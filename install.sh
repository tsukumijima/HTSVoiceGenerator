#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 HTKPath HDecodePath"
  exit -1
fi

STARTPATH=`pwd`

HTKPATH="$(cd $(dirname "$1") && pwd)/$(basename "$1")"
cd "$STARTPATH"
HDECODEPATH="$(cd $(dirname "$2") && pwd)/$(basename "$2")"
cd "$STARTPATH"

mkdir tools
cd tools
TOOLSDIR=`pwd`

# パッケージのインストール
sudo apt-get update
sudo apt-get -y install build-essential autoconf python3 ffmpeg sox libsox-fmt-all libpulse-dev libasound-dev hts-voice-nitech-jp-atr503-m001 cmake curl csh libx11-dev flac jq

# julius のビルド
wget https://github.com/julius-speech/julius/archive/v4.5.tar.gz
tar zxvf v4.5.tar.gz
mv julius-4.5 julius
cd julius
./configure
make
cd ..

# Julius 音声認識パッケージのダウンロード
wget --trust-server-names "https://osdn.net/frs/redir.php?m=jaist&f=julius%2F71011%2Fdictation-kit-4.5.zip"
unzip dictation-kit-4.5.zip
mv dictation-kit-4.5 julius-dictation-kit

# segment_adapt_windows のダウンロード
wget https://www.dropbox.com/s/vvzl4yg4rwcdjol/segment_adapt_windows-v1.0.zip
unzip segment_adapt_windows-v1.0.zip
mv segment_adapt_windows-v1.0 segment_adapt
cd segment_adapt
mv akihiro/ voices/
cp ../../patch/segment_adapt.patch .
patch -p1 -d . < segment_adapt.patch
cd ..

# HTK・HDecode・HTS for HTK のビルド
mkdir htk
tar zxvf $HTKPATH
tar zxvf $HDECODEPATH
wget http://hts.sp.nitech.ac.jp/archives/2.3/HTS-2.3_for_HTK-3.4.1.tar.bz2
# wget https://web.archive.org/web/20160605183450if_/http://hts.sp.nitech.ac.jp/archives/2.3/HTS-2.3_for_HTK-3.4.1.tar.bz2
mkdir HTS-2.3_for_HTK-3.4.1
tar jxvf HTS-2.3_for_HTK-3.4.1.tar.bz2 -C HTS-2.3_for_HTK-3.4.1
cp HTS-2.3_for_HTK-3.4.1/HTS-2.3_for_HTK-3.4.1.patch htk
cd htk
patch -p1 -d . < HTS-2.3_for_HTK-3.4.1.patch
./configure --prefix=$TOOLSDIR/htk/
make CFLAGS="-DARCH=ASCII -I$BUILDDIR/htk/HTKLib"
make install
cd ..

# hts_engine のビルド
wget http://downloads.sourceforge.net/hts-engine/hts_engine_API-1.10.tar.gz
tar zxvf hts_engine_API-1.10.tar.gz
mv hts_engine_API-1.10/ hts_engine_API-source/
cd hts_engine_API-source/
./configure --prefix=$TOOLSDIR/hts_engine_API/
make
make install
cd ..

# SPTK のビルド
wget http://downloads.sourceforge.net/sp-tk/SPTK-3.10.tar.gz
tar zxvf SPTK-3.10.tar.gz
mv SPTK-3.10/ SPTK-source/
cd SPTK-source/
./configure --prefix=$TOOLSDIR/SPTK/
make
make install
cd ..

# HTS-demo のビルド
wget http://hts.sp.nitech.ac.jp/archives/2.3/HTS-demo_NIT-ATR503-M001.tar.bz2
# wget https://web.archive.org/web/20200720111752if_/http://hts.sp.nitech.ac.jp/archives/2.3/HTS-demo_NIT-ATR503-M001.tar.bz2
tar jxvf HTS-demo_NIT-ATR503-M001.tar.bz2
cd HTS-demo_NIT-ATR503-M001/
cp ../../patch/HTS-demo.patch .
patch -p1 -d . < HTS-demo.patch
./configure --with-sptk-search-path=$TOOLSDIR/SPTK/bin --with-hts-search-path=$TOOLSDIR/htk/bin --with-hts-engine-search-path=$TOOLSDIR/hts_engine_API/bin UPPERF0=500
cd ..

# OpenJTalk のビルド
wget https://downloads.sourceforge.net/project/open-jtalk/Open%20JTalk/open_jtalk-1.11/open_jtalk-1.11.tar.gz
tar zxvf open_jtalk-1.11.tar.gz
mv open_jtalk-1.11/ open_jtalk-source/
cd open_jtalk-source/
cp ../../patch/open_jtalk.patch .
patch -p1 -d . < open_jtalk.patch
./configure --prefix=$TOOLSDIR/open_jtalk --with-hts-engine-header-path=$TOOLSDIR/hts_engine_API/include --with-hts-engine-library-path=$TOOLSDIR/hts_engine_API/lib
make
make install
cd ..

# splitAndGetLabel (音声からラベル生成) のビルド
wget https://github.com/NON906/splitAndGetLabel/archive/v0.2.tar.gz
tar zxvf v0.2.tar.gz
mv splitAndGetLabel-0.2 splitAndGetLabel
cd splitAndGetLabel
cp ../../patch/splitAndGetLabel.patch .
patch -p1 -d . < splitAndGetLabel.patch
mkdir build
cd build
cmake ..
make
cd ../..

# 解凍後のアーカイブファイルを削除
rm -f v4.5.tar.gz dictation-kit-4.5.zip segment_adapt_windows-v1.0.zip HTS-2.3_for_HTK-3.4.1.tar.bz2 hts_engine_API-1.10.tar.gz SPTK-3.10.tar.gz HTS-demo_NIT-ATR503-M001.tar.bz2 open_jtalk-1.11.tar.gz v0.2.tar.gz

