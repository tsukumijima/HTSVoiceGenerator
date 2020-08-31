#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Usage: $0 [-G APIKey] InputDirPath HTSVoicePath [OpenJTalkOption] [BaseHTSVoicePath]"
  exit -1
fi

APIMODE="J"  #J:julius, G:google cloud speech API
APIKEY=""
OPTIONS=""

STARTPATH=`pwd`

echo ""

# 引数読み込み
if [ $1 = "-G" ]; then
  APIMODE="G"
  APIKEY=$2
  INPUTDIRPATH=$(cd "$3" && pwd)
  cd "$STARTPATH"
  HTSVOICEPATH="$(cd $(dirname "$4") && pwd)/$(basename "$4")"
  cd "$STARTPATH"
  shift 4
else
  INPUTDIRPATH=$(cd "$1" && pwd)
  cd "$STARTPATH"
  HTSVOICEPATH="$(cd $(dirname "$2") && pwd)/$(basename "$2")"
  cd "$STARTPATH"
  shift 2
fi

# OpenJTalk での音声認識時に使用する音響モデル
mFlag=0
while [ $# -ge 2 -a "$(echo "$1" | cut -c 1)" = "-" ]
do
  OPTIONS=" ${OPTIONS} $1 $2 "
  if [ $1 = "-m" ]; then
    mFlag=1
  fi
  shift 2
done
if [ $# -lt 1 ]; then
  OPTIONS=" ${OPTIONS} -m /usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice "
elif [ ${mFlag} -eq 0 ]; then
  OPTIONS=" ${OPTIONS} -m \"$(cd $(dirname "$1") && pwd)/$(basename "$1")\" "
fi
cd "$STARTPATH"

cd tools
toolsDir=`pwd`

# 古い音声を削除
rm -f HTS-demo_NIT-ATR503-M001/data/raw/*
rm -f HTS-demo_NIT-ATR503-M001/data/labels/mono/*
rm -f HTS-demo_NIT-ATR503-M001/data/labels/full/*

rm -f segment_adapt/voices/*.wav
rm -f segment_adapt/voices/*.raw
rm -f segment_adapt/voices/labels/mono/*
rm -f segment_adapt/voices/labels/full/*

# SOX で raw 音声を作成
mkdir splitAndGetLabel/build/ 2> /dev/null
cd splitAndGetLabel/build/
rm -rf tmp
mkdir tmp
for file in `ls "$INPUTDIRPATH"`
do
  echo -e "Convert ${file} to ${file}.raw"

  # ffmpeg で wav に変換しておく
  ffmpeg -i ${INPUTDIRPATH}/${file} -acodec pcm_s16le -ar 44100 "${INPUTDIRPATH}/${file%.*}.wav" > /dev/null 2>&1

  # 音量を計測
  vol=`sox "${INPUTDIRPATH}/${file%.*}.wav" -n stat -v 2>&1`
  volGain=`echo "scale=9; ${vol} / 2.86" | bc`

  # raw ファイルを作成
  sox "${INPUTDIRPATH}/${file%.*}.wav" -t raw -r 16k -e signed-integer -b 16 -c 1 -B "$(pwd)/tmp/${file}.raw" vol ${volGain}

  # wav ファイルを削除
  rm "${INPUTDIRPATH}/${file%.*}.wav"
done

# splitAndGetLabel でラベルデータを作成
echo -e "\nExecute splitAndGetLabel ...\n"
if [ ${APIMODE} = "J" ] ; then
  ./splitAndGetLabel ${OPTIONS}
else
  ./splitAndGetLabel -${APIMODE} ${APIKEY} ${OPTIONS}
fi

# 音響モデルのビルド
echo -e "Build acoustic model ...\n"
cd ../../HTS-demo_NIT-ATR503-M001/
fileCount=`find data/raw -type f | wc -l`
if [ ${fileCount} -lt 503 ] ; then
  ./configure --with-sptk-search-path=${toolsDir}/SPTK/bin --with-hts-search-path=${toolsDir}/htk/bin --with-hts-engine-search-path=${toolsDir}/hts_engine_API/bin UPPERF0=500 NITER=`expr 503 \* 50 / ${fileCount}`
else
  ./configure --with-sptk-search-path=${toolsDir}/SPTK/bin --with-hts-search-path=${toolsDir}/htk/bin --with-hts-engine-search-path=${toolsDir}/hts_engine_API/bin UPPERF0=500 NITER=50
fi
make clean
make

line=`ps x | grep Training.pl | grep -v grep`
while [ "$line" != "" ]
do
  sleep 1s
  line=`ps x | grep Training.pl | grep -v grep`
done

# 生成された音響モデルを指定フォルダにコピー
cd "$STARTPATH"
cp tools/HTS-demo_NIT-ATR503-M001/voices/qst001/ver1/nitech_jp_atr503_m001.htsvoice "$HTSVOICEPATH"

echo -e "Output to $HTSVOICEPATH. Finished.\n'
