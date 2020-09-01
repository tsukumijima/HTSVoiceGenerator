
# HTSVoiceGenerator

Open JTalk などで使用される、音響モデルファイル (.htsvoice) を生成、およびその環境を構築するシェルスクリプトです。  
（注：このスクリプトを実行すると、自動的にいくつかのプログラムがダウンロードされます。  
これらのプログラムのライセンス・使用条件については、それぞれのプログラムを参照してください）  

## 動作環境

Ubuntu 20.04 LTS

## インストール方法

1. 以下のサイトの Stable release (3.4.1) ＞ Linux/Unix downloads ＞ HTK source code から HTK-3.4.1.tar.gz をダウンロードしてください。  
[http://htk.eng.cam.ac.uk/download.shtml](http://htk.eng.cam.ac.uk/download.shtml)  
（ダウンロードにはユーザー登録が必要です）


2. 以下のサイトの HDecode Download Stable Release (3.4.1) ＞ Linux/Unix downloads から HDecode-3.4.1.tar.gz をダウンロードしてください。  
[http://htk.eng.cam.ac.uk/prot-docs/hdecode.shtml](http://htk.eng.cam.ac.uk/prot-docs/hdecode.shtml)  
（ダウンロードにはユーザー登録が必要です）


3. git cloneします。
```
git clone https://github.com/tsukumijima/HTSVoiceGenerator.git
```


4. 以下のコマンドを実行し、インストールします。
```
cd HTSVoiceGenerator/
sh install.sh /path/to/HTK-3.4.1.tar.gz /path/to/HDecode-3.4.1.tar.gz
```
（ /path/to/ には HTK-3.4.1.tar.gz や HDecode-3.4.1.tar.gz をダウンロードしたディレクトリを指定してください）  

## 実行方法

```
cd HTSVoiceGenerator/
sh make_htsvoice.sh 音声ファイルのディレクトリ /path/to/result.htsvoice
```
（音声ファイルのディレクトリ とは、音源となる wav や mp3 が入っているディレクトリのことです）   
（生成した音響モデルファイルは /path/to/result.htsvoice に保存されます）  
（実行中は多くのメモリ領域を使用しますので、あらかじめ swap ファイルを追加しておくことをおすすめします）  
（-T を指定すると音声ファイルのディレクトリから同じファイル名のテキストファイルからラベルを作成します）  
（完了まで数時間～数日程度かかります）

## 追加機能

### Google Cloud Speech API を使用する

以下のコマンドで実行することで音声認識の一部の処理に Google Cloud Speech API を使用することができます。  
（ APIKEY の取得にはユーザー登録が必要です）

```
cd HTSVoiceGenerator/
sh make_htsvoice.sh -G APIKEY 音声ファイルのディレクトリ /path/to/result.htsvoice
```

### 単語辞書の最適化

以下のコマンドを実行することで単語辞書を最適化することができます。  
（注：このコマンドを実行すると先述の「Google Cloud Speech API を使用する」を行うことができなくなります。何らかの事情で API を使用できないときにのみ使用してください）  
（完了まで数時間程度かかります）

```
cd HTSVoiceGenerator/
sh make_dic_julius.sh
```
