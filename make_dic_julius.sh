#!/bin/bash

cd tools

rm -f bccwj.60k.pdp_new.htkdic

loopCnt=0
cat julius-dictation-kit/model/lang_m/bccwj.60k.pdp.htkdic | while read juliusLine
do
	if [ ${loopCnt} -lt 1 ] ; then
		echo "${juliusLine}" >> bccwj.60k.pdp_new.htkdic

		loopCnt=`expr ${loopCnt} + 1`
		continue
	fi

	wordCnt=2
	word=`echo "${juliusLine}" | cut -f 2`
	while [ `echo "${word}" | cut -c 1` != "[" ]
	do
		wordCnt=`expr ${wordCnt} + 1`
		word=`echo "${juliusLine}" | cut -f ${wordCnt}`
	done	
	wordEnd=`expr $(echo "${word}" | wc -c) - 2`
	juliusWord=`echo "${word}" | cut -c 2-${wordEnd}`

	if [ ${loopCnt} -lt 3 ] ; then
		outputLine=`echo "${juliusLine}" | sed -e "s/\[${juliusWord}\]/\[${juliusWord}　\]/"`
		echo "${outputLine}" >> bccwj.60k.pdp_new.htkdic

		loopCnt=`expr ${loopCnt} + 1`
		continue
	fi

	grep -E "^${juliusWord}," open_jtalk/mecab-naist-jdic/naist-jdic.csv | while read openJTalkLine
	do
		openJTalkRead=`echo "${openJTalkLine}" | cut -d "," -f 13`
		if [ "${openJTalkRead}" = "*" ] ; then
			continue
		fi

		outputLine=`echo "${juliusLine}" | sed -e "s/\[${juliusWord}\]/\[${juliusWord}　\]/"`
		echo "${outputLine}" >> bccwj.60k.pdp_new.htkdic
		break
	done
done

rm -f tmp.csv

cat open_jtalk/mecab-naist-jdic/naist-jdic.csv | while read openJTalkLine
do
	openJTalkRead=`echo "${openJTalkLine}" | cut -d "," -f 13`
	if [ "${openJTalkRead}" = "*" ] ; then
		continue
	fi

	openJTalkWord=`echo "${openJTalkLine}" | cut -d "," -f 1`

	if [ "$(grep "\[${openJTalkWord}\]" julius-dictation-kit/model/lang_m/bccwj.60k.pdp.htkdic)" != "" ] ; then
		outputLine="${openJTalkWord}　,$(echo "${openJTalkLine}" | cut -d "," -f 2-)"
		echo "${outputLine}" >> tmp.csv 
	fi	
done

mv -f tmp.csv open_jtalk/mecab-naist-jdic/naist-jdic.csv

cd open_jtalk/
./configure --prefix=$TOOLSDIR/open_jtalk --with-hts-engine-header-path=$TOOLSDIR/hts_engine_API/include --with-hts-engine-library-path=$TOOLSDIR/hts_engine_API/lib
make
make install
cd ..
