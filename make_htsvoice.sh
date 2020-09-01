#!/bin/bash

if [ $# -lt 2 ]; then
  echo ""
  echo "Usage: $0 [-G APIKey] [-T] InputDirPath HTSVoicePath [OpenJTalkOption] [BaseHTSVoicePath]"
  echo ""
  echo "-G APIKey : Specify API key only when using google cloud speech API"
  echo "-T        : Create a label from a text file with the same name as the audio file in InputDirPath"
  echo "InputDirPath (Required) : Folder with audio files used for training"
  echo "HTSVoicePath (Required) : File path of htsvoice file to output"
  echo "OpenJTalkOption  : Arguments to pass to Open JTalk used when creating the label"
  echo "BaseHTSVoicePath : File path of the acoustic model to pass to Open JTalk used when creating the label"
  echo ""
  exit -1
fi

APIMODE="J" # J:julius, T:textfile, G:google cloud speech API
APIKEY=""
OPTIONS=""

UPPERF0=500 # 基本周波数抽出の上限 (Hz) (女性の声の場合は 500 (Hz)・男性の声の場合は 200 (Hz) 程度が良いらしい)
NITER=10 # トレーニングの反復回数 (増やすと精度が上がるらしいが、その分時間がかかる)

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
elif [ $1 = "-T" ]; then
  APIMODE="T"
  INPUTDIRPATH=$(cd "$2" && pwd)
  cd "$STARTPATH"
  HTSVOICEPATH="$(cd $(dirname "$3") && pwd)/$(basename "$3")"
  cd "$STARTPATH"
  shift 3
else
  INPUTDIRPATH=$(cd "$1" && pwd)
  cd "$STARTPATH"
  HTSVOICEPATH="$(cd $(dirname "$2") && pwd)/$(basename "$2")"
  cd "$STARTPATH"
  shift 2
fi

# OpenJTalk でのラベル作成時に使用する音響モデル
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
  # デフォルトの音響モデルを利用
  OPTIONS=" ${OPTIONS} -m /usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice "
elif [ ${mFlag} -eq 0 ]; then
  # 指定された音響モデルを利用
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
  # テキストファイルを除外
  if [ "${file##*.}" != 'txt' ]; then

    echo -e "Convert ${file} to ${file%.*}.raw"

    # ffmpeg で wav に変換しておく
    ffmpeg -i ${INPUTDIRPATH}/${file} -acodec pcm_s16le -ar 44100 "${INPUTDIRPATH}/${file%.*}.wav" > /dev/null 2>&1

    # 音量を計測
    vol=`sox "${INPUTDIRPATH}/${file%.*}.wav" -n stat -v 2>&1`
    volGain=`echo "scale=9; ${vol} / 2.86" | bc`

    # raw ファイルを作成
    sox "${INPUTDIRPATH}/${file%.*}.wav" -t raw -r 16k -e signed-integer -b 16 -c 1 -B "$(pwd)/tmp/${file%.*}.raw" vol ${volGain}

    # wav ファイルを削除
    rm "${INPUTDIRPATH}/${file%.*}.wav"

  fi
done

# make_label_fromtext.py でラベルデータを作成
if [ ${APIMODE} = "T" ] ; then

  # raw ファイルをコピー
  cp tmp/*.raw $STARTPATH/tools/segment_adapt/voices/

  # make_label_fromtext.py でテキストファイルからラベルデータを作成
  echo -e "\nExecute make_label_fromtext.py ...\n"
  python3 "$STARTPATH/make_label_fromtext.py" ${INPUTDIRPATH} "${OPTIONS}"

  # segment_adapt.pl を実行
  cd $STARTPATH/tools/segment_adapt/
  perl "$STARTPATH/tools/segment_adapt/segment_adapt.pl"

  # ラベルと raw ファイルを HTS-demo_NIT-ATR503-M001 内に配置
  cp $STARTPATH/tools/segment_adapt/voices/data/raw/*.raw $STARTPATH/tools/HTS-demo_NIT-ATR503-M001/data/raw/
  cp $STARTPATH/tools/segment_adapt/voices/data/full/*.lab $STARTPATH/tools/HTS-demo_NIT-ATR503-M001/data/labels/full/
  cp $STARTPATH/tools/segment_adapt/voices/data/mono/*.lab $STARTPATH/tools/HTS-demo_NIT-ATR503-M001/data/labels/mono/

# splitAndGetLabel でラベルデータを作成
elif [ ${APIMODE} = "J" ] ; then
  echo -e "\nExecute splitAndGetLabel ..."
  ./splitAndGetLabel ${OPTIONS}
else
  echo -e "\nExecute splitAndGetLabel ..."
  ./splitAndGetLabel -${APIMODE} ${APIKEY} ${OPTIONS}
fi

# 音響モデルのビルド
echo -e "Build acoustic model ..."

cd $STARTPATH/tools/HTS-demo_NIT-ATR503-M001/
fileCount=`find data/raw -type f | wc -l`
echo -e "File count: ${fileCount}\n"

if [ ${fileCount} -lt 503 ] ; then
  # ファイル数が 503 以下 (ファイル数が少なくなればなるほどトレーニングの反復回数が増える)
  ./configure --with-sptk-search-path=${toolsDir}/SPTK/bin --with-hts-search-path=${toolsDir}/htk/bin --with-hts-engine-search-path=${toolsDir}/hts_engine_API/bin UPPERF0=${UPPERF0} NITER=`expr 503 \* ${NITER} / ${fileCount}`
else
  # ファイル数が 503 以上
  ./configure --with-sptk-search-path=${toolsDir}/SPTK/bin --with-hts-search-path=${toolsDir}/htk/bin --with-hts-engine-search-path=${toolsDir}/hts_engine_API/bin UPPERF0=${UPPERF0} NITER=${NITER}
fi

# make を実行
make clean
make

# 5 秒スリープ
echo -e "\n---------------------------------------------------------------------------------------"
echo -e "\nRunning training ...\n"
echo -e "You can check the training log by running \"tail -f tools/HTS-demo_NIT-ATR503-M001/log\"."
echo -e "If you want to kill the training, "
echo -e "run \"ps aux | grep Training.pl | grep -v grep | awk'{ print \"kill -9\", \$2 }'| sh\"."
echo -e "\n---------------------------------------------------------------------------------------\n"
sleep 5

# プロセスが実行されている間待機する
# 出力内容は tail -f tools/HTS-demo_NIT-ATR503-M001/log でも確認できる
# 強制終了したいときは ps aux | grep Training.pl | grep -v grep | awk '{ print "kill -9", $2 }' | sh を実行

# 初期化
line=`ps x | grep Training.pl | grep -v grep`
lineCount=0

# プロセスが動いていれば
while [ "$line" != "" ]
do
  # 0.01 秒スリープ
  sleep 0.01s
  
  # プロセスの実行状態を取得
  line=`ps x | grep Training.pl | grep -v grep`

  # 更新されたログを随時表示
  lineCount_new=`cat log | wc -l`
  if [ `expr ${lineCount_new}` -gt `expr ${lineCount}` ]; then
    log=`cat log | head -${lineCount_new} | tail`
    echo -e "${log}" # まだ表示していない行だけ出力
  fi
  lineCount=`expr ${lineCount_new}`
done

# 生成された音響モデルを指定フォルダにコピー
cd "$STARTPATH"
if [ -e tools/HTS-demo_NIT-ATR503-M001/voices/qst001/ver1/nitech_jp_atr503_m001.htsvoice ]; then
  cp tools/HTS-demo_NIT-ATR503-M001/voices/qst001/ver1/nitech_jp_atr503_m001.htsvoice "${HTSVOICEPATH}"
  echo -e "\n\nOutput to \"${HTSVOICEPATH}\". Done.\n"
else
  echo -e "\n\nCouldn't Output to \"${HTSVOICEPATH}\". Failed.\n"
fi
