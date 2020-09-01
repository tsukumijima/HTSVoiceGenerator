
# import
import os
import sys
import glob
import argparse
import subprocess
from pprint import pprint


def main():

    # 引数を設定・取得
    parser = argparse.ArgumentParser(formatter_class = argparse.RawTextHelpFormatter)
    parser.add_argument('InputFolderPath', help = 'Specify a folder with text')
    parser.add_argument('OpenJTalkOption', help = 'Specify the argument to pass to Open JTalk used when creating the label')
    args = parser.parse_args()

    # カレントフォルダ
    current_folder = os.path.dirname(__file__) + '/'
    print(current_folder)

    # 入力フォルダ
    input_folder = args.InputFolderPath.strip().rstrip('/') + '/'

    # 出力フォルダ
    output_folder = current_folder + 'tools/segment_adapt/voices/'

    # Open JTalk
    open_jtalk = current_folder + 'tools/open_jtalk/bin/open_jtalk'
    open_jtalk_dic = current_folder + 'tools/open_jtalk/dic/'
    open_jtalk_option = args.OpenJTalkOption.strip()
    open_jtalk_log = current_folder + 'tmp.log'

    # フォルダ作成
    os.makedirs(output_folder, exist_ok = True)
    os.makedirs(output_folder + 'labels/full/', exist_ok = True)
    os.makedirs(output_folder + 'labels/mono/', exist_ok = True)

    print('Input folder: ' + input_folder)
    print('Output folder: ' + output_folder)
    print()

    # テキストファイルのリスト
    textfile_list = sorted(glob.glob(input_folder + '*.txt'))

    # テキストファイルごとに
    index = 0
    for textfile in textfile_list:

        # index を足す
        index += 1

        # 拡張子なしファイル名
        textfile_id = os.path.splitext(os.path.basename(textfile))[0]

        # ファイルを開く
        with open(textfile, encoding = 'utf-8') as fp:
            
            # ファイルを読み込む
            text = fp.read()

            # 改行を削除
            text = text.replace('\n', '　')
            text = text.replace('{player}', '')
            print('Text: ' + text)

        # OpenJTalk を実行
        open_jtalk_command = 'echo "' + text + '" | ' + open_jtalk + ' -x ' + open_jtalk_dic + ' ' + open_jtalk_option + ' -ot ' + open_jtalk_log + ' 2> /dev/null'
        subprocess.run(open_jtalk_command, shell = True)

        # 出力されたログを開く
        with open(open_jtalk_log, encoding = 'utf-8') as log:

            # ログを読み込む
            lines = log.readlines()

        # ログが空でないなら
        if ''.join(lines) != "":

            # 音声ファイルの出力先
            voice_old = output_folder + textfile_id + '.raw'
            voice_new = output_folder + 'voices_' + str(index).zfill(4) + '.raw'
            print('Voice: ' + voice_old)
            print('Voice rename: ' + voice_new)

            # 音声ファイルを連番のファイル名にリネーム
            os.rename(voice_old, voice_new)

            # フルコンテキスト (full) ラベルの出力先
            label_full = output_folder + 'labels/full/voices_' + str(index).zfill(4) + '.lab'
            print('Label (full): ' + label_full)

            # 単音 (mono) ラベルの出力先
            label_mono = output_folder + 'labels/mono/voices_' + str(index).zfill(4) + '.lab'
            print('Label (mono): ' + label_mono)

            # フルコンテキストラベルを書き込む
            for line in lines:
                if line.find('0000') >= 0 and line.find('xx/') >= 0:
                    with open(label_full, mode = 'a', encoding = 'utf-8') as full_rfp:
                        full_rfp.write(line)

            # 単音ラベルを書き込む
            # 先ほど書きこんだフルコンテキストラベルを開く
            with open(label_full, mode = 'rt', encoding = 'utf-8') as full_wfp:

                # 行ごとに
                for line in full_wfp:
                    mono = []
                    words = line.split(' ')

                    # 文字ごと
                    for word in words:
                        if '+' in word:
                            ws1 = word.split('+')[0]
                            ws2 = ws1.split('-')[1]
                            mono.append(ws2)
                            _str = ' '.join(map(str, mono))
                        else:
                            mono.append(word)

                    # 単音ラベルを書き込み
                    mono_str = ' '.join(map(str, mono))
                    # print(mono_str)
                    with open(label_mono, mode = 'a', encoding = 'utf-8') as mono_wfp:
                        mono_wfp.write(mono_str + '\n')

        # ログが空の場合、処理をスキップする
        else:
            # インデックスを減らす
            index -= 1

            # ボイスファイルを削除
            os.remove(output_folder + textfile_id + '.raw')

        print()

    # ログを削除
    os.remove(open_jtalk_log)


if __name__ == '__main__':
    main()
