# 無線制御(Acrabの実装解説)
- 書いた人: Kenichi Ito(nichiden_27)
- 更新: Hanaka Satoh(nichiden_28)
- 更新日時: 2018/08/26
- 実行に必要な知識・技能: Web制作、JavaScript
- 難易度: 3/練習・勉強が必要
- 情報の必須度: 4/担当者には必須

## 概要
[無線制御(Acrab)](acrab.html)から`Acrab`の具体的な実装の解説を分離した記事です。

`Acrab`のソースコードを読む、あるいは書き換える際に参考にしてください。

## acrab_conf.json
`Acrab`の設定ファイルである。
JSONファイルのため構造の概略のみ示す。
```
├── "ip" [Pisciumとの通信用]
│   ├── "N" [北天受信機のIPアドレス]
│   └── "S" [南天受信機のIPアドレス]
├── "port" [出力ポート用]
│   ├── "And" [星座or投影機名の三文字コード]
│   │   ├── "name" [ボタンに表示する名前]
│   │   ├── "box" [北天なら"N"/南天なら"N"/両方なら"NS"]
│   │   └── "pin" [投影機とピン番号の対応]
│   └── (以下同様)
└── "group" [星座や投影機のグループを定義]
    ├── "Set" [全点灯の三文字コード]
    │   └── "name" [ボタンに表示する名前]
    ├── "Cle" [全消灯の三文字コード]
    │   └── "name" [ボタンに表示する名前]
    ├── "Spc" [グループ名の三文字コード]
    │   ├── "name" [ボタンに表示する名前]
    │   └── "value" [配列: グループに属する星座or投影機を列挙]
    └── (以下同様)
```
三文字コードというのは、プログラム中で**星座・投影機・そのグループ**を区別するため一意に割り振った三文字を指す。
星座にはもともと[この形式の略符が用意されている](http://www.nao.ac.jp/new-info/constellation2.html)こともあり、文字数を統一して可読性を高めることを目指した。
また、`ACRAB`ディレクトリ内に`88星座+略符一覧.txt`を用意してみたので、良ければ参考にしてほしい。

例えば星座絵のピン番号を入れ替える際には、`port.(星座名).pin`を書き換えれば良い。(※北天、南天それぞれでpin番号が重複しないようにする)
`Piscium`側に設定を反映させるためページをリロードすること。

## acrab_main.js
`Acrab`全体に関わるコードや、「メイン」画面で使用するコードを記述した。

### 読み込み時の処理
ページを読み込んだ後に一度だけ実行したい処理がある。
JSはスクリプト言語なので、main関数のようなものはなくコードの頭から順に読み込まれる。

通常は関数を定義しても呼び出されるまで何も起こらないが、`(function(){})()`の形式のものは読み込んだ時点で実行される。
これを**即時関数**といい、初期設定の適用などに使える。

また、コード中に`$(function(){})`もあるが、これは即時関数ではない。
$がついたものはjQueryの**readyイベント**といい、**HTMLが全てロードされた時点で実行される**。
ページを書き換えるような処理ではページが読み込まれていないと意味がないので、こちらを使うようにしよう。

即時関数・readyイベントで行っている処理は以下の通り。
冒頭の`acrab_conf.json`の取得とパースだけはreadyイベントでは上手くいかなかったので即時関数を使用している。

- `acrab_conf.json`の取得とパース
    - `$.getJSON()`を使うだけ
- `port`と`group`の`name`をボタンに表示
    - `$.each()`で配列の全要素にループ処理できる
- ピン番号の設定を`Piscium`に送信(`pinSettingSend()`)
- 各ボタンにclickイベントを追加
    - `.main_button`というクラスの要素を取得して`$.each()`
    - HTMLに手作業で書くのが面倒なので、クラスからボタンの種類を判定して最適な関数を実行する仕組み
- 更新ボタン、明るさスライダーの処理を追加
- タブの切り替え
    - 各タブの画面はそれぞれ`.content`クラスに入っている
    - 一度全てを非表示にした後、押したタブの順番と同じ順番の画面のみ表示する

開発の途中に順次追加したのでかなりグチャグチャになっている。
自由に読みやすく変更して構わない。

### getRequest(address, data)
`address`にURLパラメータとして`data`を付けて送信する関数。
jQueryの`get()`や`Deferred`を使用している。
```js
data = data || {}
console.info(address + ': ' + JSON.stringify(data));
var deferred = $.Deferred(); // 非同期通信なので完了時にデータを渡す処理
$.get({
  url: address, dataType: 'json', timeout: 1000, data: data
}).done(function(res) {
  console.debug(res);
  if(address.match(ip.N)) $('#wifi-icons #north').text('正常受信中').removeClass('error');
  else if(address.match(ip.S)) $('#wifi-icons #south').text('正常受信中').removeClass('error');
  deferred.resolve(res);
}).fail(function(xhr) {
  console.error(xhr.status+' '+xhr.statusText);
  if(address.match(ip.N)) $('#wifi-icons #north').text('接続なし').addClass('error');
  else if(address.match(ip.S)) $('#wifi-icons #south').text('接続なし').addClass('error');
  deferred.reject;
});
return deferred;
```
`$.get()`は、指定したURLにGETリクエストを送信する。
`data`に連想配列を指定するとURLパラメータに整形してくれる嬉しい機能付きだ。
また、通信が切れている時に固まらないよう、1500msのタイムアウトを設定している。(1000msだと通信失敗することが多かった。)

その後の`.done()`や`.fail()`にはそれぞれ通信成功時・失敗時の処理を書く。
ここでは通信するたびにブラウザコンソールに結果を出力し、受信状況の欄を更新するようになっている。

さて、`Piscium`にコマンドを送ると、**各ポートの状態を0か1で表したjsonデータ**が返る。
`dataType: 'json'`としておけばパースまでやってくれるようだ。
これを関数の戻り値としたいが、これには工夫が必要になる。

`$.get()`のようなAjax通信は**非同期処理**を採用しており、リクエストを送った後応答を待たずに関数が終了してしまう。
そのため、送られてくるはずのデータを戻り値に入れることができない。

そこで、`$.Deferred`を利用する。
ググれば出てくるため詳細は省くが、Deferredオブジェクトを一旦返し**通信が終了してからデータを格納する**ことができる。
また、通信が失敗した場合`deferred.reject`すると以上終了させることもできる。

### checkStatus(stat)
`Piscium`から送られてくるjsonをパースしたオブジェクトから**各星座絵・投影機のオンオフ状況を確認する**。
基本的に`getRequest()`で通信した後はこれを呼ぶようにして、表示を常に最新に保つべきである。
`getRequest()`は非同期関数なので、以下のコード片のように`.done()`を使う。
```js
getRequest(address, data).done(function(res){checkStatus(res)});
```
ボタンはHTML側で以下のように三文字コードのIDが振られている。
````HTML
<!-- index.html -->
<button class="main_button constellation" id="And">And</button>
````
三文字コードは`port`や`group`に入っているので、`$.each()`ループを回して巡回する。
各ボタンに`on`クラスを追加すると色などが変わる仕組みだ。
```js
  $.each(port, function(key){ // 星座|投影機ごと
    if(stat[key] === 1) $('[id='+key+']').addClass('on');
    else if(stat[key] === 0) $('[id='+key+']').removeClass('on');
  });
```
`group`に関しても基本は変わらないが、こちらは**属している星座絵全てが点灯していなければオンにならない**。
例えば、「夏の大三角」ボタンを押すと「こと/わし/はくちょう」が点灯するが、このうち一つでも消すと「夏の大三角」もオフの表示になる。
```js
  $.each(group, function(key){ // 星座グループごと
    if(!this.value) return;
    var isOn = true;
    $.each(this.value, function(){isOn &= $('#'+this).hasClass('on');}); // 各星座がオンかどうかのANDをとる
    if(isOn) $('[id='+key+']').addClass('on');
    else $('[id='+key+']').removeClass('on');
  });
  return;
}
```

### pinSettingSend()
`Piscium`には、`(ip)/setConstellationName/status.json`にアクセスすることでピンごとに名前を設定する機能がある。
これで`(ip)/setPort/status.json?And=0`のように三文字コードをURLに使えるようになり、ユーザが見てもわかりやすい。

`acrab_conf.json`が読み込まれた後のタイミングで実行される。また、受信状況の「更新」ボタンを押しても実行される。(北天・南天とも)
これは`PISCIUM`の再起動時に、ページを再読み込みしなくても、「更新」ボタンを押せば`PISCIUM`にピン名称を送れるようにするためである。
`port.(三文字コード).pin`の中身を順に取得して`getRequest()`に渡すという流れである。

### buttonオブジェクト
メイン画面のボタンは、**星座絵/投影機/全点(消)灯/グループ**の四種類ある。
それぞれに合った処理をするため、`button`オブジェクトを作成し必要なメソッドをまとめるようにした。

#### 星座絵: button.constellation(obj)
星座絵は南天か北天に分かれている。
南北は`port[(三文字コード)].box`から判定し、受信機のアドレスを`ip[(NかS)]`で取得する。

また、ボタンのオンオフ状態と逆の真偽値を`data`に入れておく。
後は`getRequest()`を呼んで終了する。
```js
var address = ip[port[obj.id].box] + 'setPort/status.json';
var data = {}
data[obj.id] = button.stat(obj);
getRequest(address, data).done(function(res){checkStatus(res)});
return;
```

#### 投影機: button.projector(obj)
星座絵以外の投影機は南北両方に付いているのが普通である。
そのため**受信機の数だけ同じリクエストを送る**必要がある。
`ip`の各要素について`$.each()`を回すことでこれを実現する。
```js
$.each(ip, function(){
  var address = this + 'setPort/status.json';
  var data = {};
  data[obj.id] = button.stat(obj);
  getRequest(address, data).done(function(res){checkStatus(res)});
});
return;
```

#### 全点(消)灯: button.all(obj)
`Piscium`側の全点灯(allSet)・全消灯(allClear)を使う場合。
コードは`button.projector(obj)`と似ているので省略。

`Piscium`側の負荷の関係で、今のところ全点灯は使うべきでないようだ。

#### グループ: button.group(obj)
「夏の大三角」「黄道十二星座」と言った星座のグループ。
実はこれが一番面倒である。
理由は**各星座絵が南北にばらけていることがある**ため。

そのため、

1. `ip`からIPアドレスを取得してURLを作成
1. `group[(三文字コード).value]`で`$.each()`を回し、南北判定していずれかの`data`に追加
1. `req`オブジェクトに南北それぞれのデータを入れ、`getRequest()`

という手順を踏んでいる。

実は、本番前にさらに一段階手順を増やした。
星座絵を10個弱同時に点灯すると電源が不安定化する事象を確認したため、回避のため**少数ずつ分けて点灯する**よう変更したのである。
このため新たに`each_slice()`と`sleep_ms()`という関数を定義した。
これらの詳細は後述する。

#### ボタンの状態を取得する: button.stat(obj)
ボタンがオンかオフかは、`on`クラスを持っているかどうかで分かる。
`stat()`にボタンのオブジェクトを渡すと、現在の状態の逆の値を返す。
```js
return ($(obj).hasClass('on') ? 0 : 1);
```

### each_slice(obj, n)
投影機を複数点灯・消灯する際一回あたりの数を抑えるのに使用する。
`obj`にオブジェクトを、`n`に最大数を指定すると`obj`をn要素ごとに切り分けたオブジェクトの配列を返す。
```js
each_slice({"Ari":1,"Cnc":1,"Gem":1,"Leo":1,"Aqr":1,"Cap":1,"Psc":1},3)
-> [{"Ari":1,"Cnc":1,"Gem":1},{"Leo":1,"Aqr":1,"Cap":1},{"Psc":1}]
```
ただし、例外として"St1"と"St2"をキーにもつ場合は1要素のオブジェクトに分ける。
これは、こうとうの負荷があまりに大きいため他の投影機と同時に点灯することを避けるためである。

アルゴリズムとしては、n要素ずつ切ったものをfor文内でオブジェクトに追加していくだけなのでコードは省略する。

### sleep_ms(T)
`getRequest()`が`each_slice()`により複数回に別れる場合に、間隔を十分取るための関数。
これがマイコンならば`delay()`のような関数が標準で用意されるところだが、ブラウザにはそんなものはないので作るしかない。
下のコードを見れば分かるように、ひたすら時刻を取得して最初との差が`T`を超えたら抜けるという作戦になっている。
```js
var d = new Date().getTime();
var dd = new Date().getTime();
while(dd < d+T) dd = new Date().getTime();
```

遅らせる時間だが、100 msとした。
LEDの突入電流が流れる時間は数ms程度なので、十分大きくかつ人間には長すぎない程度と判断している。

## scenarioディレクトリ
`scenario/`以下には、番組の指示書を`Acrab`から読み取れるようJSON形式に変換したJSONファイルが入っている。

### *.json
JSONファイルの構造を簡単に示す。
```
├── "info" [番組情報]
│   ├── "day" [(ライブ解説の場合)何日目か]
│   ├── "title" [番組名]
│   └── "name" [担当者名]
└── "script" [配列: 指示が入る部分]
    ├── 0
    │   ├── "word" [セリフ: 0番目は空欄にする]
    │   ├── "timing" [タイミング: 0番目は空欄にする]
    │   └── "projector" [投影機]
    │       ├── "(三文字コード)" [点灯なら1/消灯なら0]
    │       └── (以下同様)
    ├── 1
    │   ├── "word" [セリフ]
    │   ├── "timing" [タイミング]
    │   └── "projector" [投影機]
    │       ├── "(三文字コード)" [点灯なら1/消灯なら0]
    │       └── (以下同様)
    └── (以下同様)
```
`info`オブジェクト内には、番組のメタデータに相当する情報が入っている。
番組選択画面で番組を選びやすくする為、`day`に**公演日**の情報も入れるようにした。
なお、ソフトは駒場祭を通じて上演されるので実際には(ソフト,一日目,二日目,三日目)の四つに分かれる。

`script`以下が**セリフやタイミング**を格納する部分である。
配列の形で並べてあり、上から順番に時系列で並んでいる必要がある。

配列の0番目は特別な部分で、公演の**開始前から点灯**したい投影機に使用する。
このため、先頭のセリフとタイミングは空欄にする必要がある。

`timing`に`pre`を指定すると「(セリフ)の**言い始め**」、`post`を指定すると「(セリフ)の**言い終り**」と画面に表示される。
セリフの前後以外のタイミングを指定したければ、「〜の」につながる形で**自由に書けばそのまま表示**される。

最後に、JSONファイルの例を示しておく。
```json
{
  "info": {
    "day": "sample",
    "title": "とてもわかりやすい星座解説",
    "name": "星見太郎"
  },
  "scenario":[
    {
      "timing": "",
      "word": "",
      "projector": {
        "Fst": 1,
        "Gxy": 1
      }
    }, {
      "timing": "post",
      "word": "プラネタリウムはいかがでしょう",
      "projector": {
        "St1": 1,
        "St2": 1
      }
    }
  ]
 }
```
28で使ったJSONファイルは一旦そのまま残してあるので、`Acrab`の動作テスト用やJSONファイルの書き方例として参考にしてほしい。

## scenario_list.json
後述する`acrab-scenario.js`で、`Acrab`にサーバの指示書ファイルの数を渡すための指示書ファイルのリスト。
`GRAFFIAS`で生成できる。作り方は[無線制御(GRAFFIAS)](graffias.html)参照のこと。

## acrab-scenario.js
「公演用画面」のためのコード。
分量が多くなったためmainと分けることにした。

### ページの初期化関連
前述の通り、指示書は番組ごとのJSONファイルに分けて`scenario/`以下に保存されている。
`acrab_main.js`と同様に、jQueryの`$.getJSON()`を用いて取得とパースを行っている。

`Acrab`はブラウザ側だけで動作しているため、サーバにいくつの指示書ファイルがあるかを直接取得できない。  
このため、先述した`scenario_list.json`をjQueryの`$.ajax()`を用いることで取得・パースし、配列の要素数から指示書ファイルの数を得る方式にした。  
`$.ajax()`は本来非同期通信に用いるものであるが、非同期のままだと`scenariolist`にデータが入らなかったため`async: false`にすることで無理矢理対応した。  
本当は非同期通信のまま`$.Deferred`などを使った方がいい気がするが、ページ読み込み時のみの処理なので妥協してしまったところ。読み込み時に気になるようなら書き直してほしい。
```js
$.ajax({
  type: "GET", 
  url: "scenario_list.json",
  async: false,
  success: function(data){
    scenariolist = data.scenariolist;
  }
  });

for(var i=0;i< scenariolist.length;i++){ scenario_file[i] = $.getJSON(scenariolist[i]); }
```

指示書ファイルを取得したら、番組選択メニューにタイトルと担当者名を追加する。
`<option>`や`<optgroup>`というのはHTMLのセレクトボックス用のタグで、前者が選択項目、後者が項目をまとめる見出しだ。
特に工夫したわけではないので解説はしない。
ググりながらコードを読んで理解してほしい。

最後の`$('select#select').change()`は、セレクトボックスが更新された際に呼ばれるメソッドを指定している。
`getScenarioData()`を使うと、該当する番号の指示書ファイルを読み込む。
```js
  /*** Initialize select box ***/
  $.when.apply($, scenario_file).done(function(){ // シナリオファイルが全部取得できたら<option>と<optgroup>追加
    $.each(arguments, function(index){ // argumentsに取得したjsonが全部入ってるのでそれぞれ読む
      var init_info = this[0].info;
      var $dayGroup = $('#select > optgroup[label='+init_info.day+']'); // <option>を入れる<optgroup>
      if(!$dayGroup[0]){
        $('#select').append($('<optgroup>', {label: init_info.day}));
        $dayGroup = $('#select > optgroup[label='+init_info.day+']');
      }
      $dayGroup.append($('<option>', {
        value: index,
        text: init_info.name + ' -  ' + init_info.title
      }));
    });
    $('select#select').change(function(){
      getScenarioData($(this).val());
    });
  }).fail(function(xhr){console.error(xhr.status+' '+xhr.statusText);});
  getScenarioData(0);
```

### 指示書データの取得と表示
#### getScenarioData(num)
`num`番目の**指示書ファイルを取得**し、JSONとしてパースする。
取得を終えたら、`scenarioInit()`を呼び出す。
```js
function getScenarioData(num){
  console.debug('getScenarioData called. num: '+num);
  $.when($.getJSON('scenario/'+ num +'.json')).done(function(data){
    info = data.info;
    scenario = data.scenario;
    scenarioInit();
  });
}
```

#### scenarioInit()
取得された**指示書のデータ**(`scenario`)**を画面に表示**する。
情報が表示される要素にはHTML側で該当するタグを付与してある。

各要素に何番目の指示が表示されるかを管理するため、`scenario{数字}`という名称のクラスを`scenario0`から順に追加するようになっている。
```js
function scenarioInit(){
  $('#scenario_prev').html('(前のシーンが表示されます)').addClass('scenario0').attr('onclick', 'goPrev();').prop('disabled', true);
  viewScript('#scenario_now', 0);
  $('#scenario_now').addClass('scenario1').prop('disabled', true);
  viewScript('#scenario_next', 1);
  $('#scenario_next').addClass('scenario2').attr('onclick', 'goNext();').prop('disabled', true);
  $('#scenario_skipnext').html('Skip').prop('disabled', true);
  $('#scenario_skipnext').addClass('scenario2').attr('onclick','skipNext();').prop('disabled',true);
  $('#scenario_number').html('1/' + scenario.length);
  $('#progress_bar progress').attr('pass_time', '00:00:00');
}
```

#### viewScript(id, index)
`id`のIDを持つ要素に、 `index`番目の**セリフ・タイミング・指示**を表示する。
タイミング等の表記を変えたければ、ここを編集すれば良い。
```js
function viewScript(id, index){
  if($(id).is(':disabled'))$(id).prop('disabled', false);
  $(id).html(function(){
    var res = ''
    if(!scenario[index].word) res += '開始直後'
    else {
      res += '「'+scenario[index].word+'」の';
      switch(scenario[index].timing){
        case 'pre': res += '前'; break;
        case 'post': res += '後'; break;
        default: res +=  scenario[index].timing; break;
      }
    }
    $.each(scenario[index].projector, function(key){
      res += '<br>' + port[key].name + 'を' + (this == 1 ? '点灯' : '消灯');
    });
    return res;
  });
}
```

### timer_buttonオブジェクト
#### ボタン関連
**「開始」「停止」「再開」「リセット」**の四つのボタンの動きを管理する。
`timer_button`には四つのメンバ関数が用意されており、それぞれが各ボタンが押された際に呼ばれる。

なお画面ではボタンは二つに見えるが、内部的には四つのボタンの表示/非表示を切り替えて内容が変わるように見せている。
以下にそれぞれの動作内容を簡単に記す(「」内はボタン名称)。

- timer_button.start()
    * 投影機に0番目(番組開始前)の指示を送信
    * **セレクトボックス**を無効化・「**次へ**」を有効化
    * **タイマー**を動かす
    * 「**開始**」を「**停止**」に、「**リセット**」を無効化
- timer_button.stop()
    * **タイマー**を止める
    *「**停止**」を「**再開**」に、「**リセット**」を有効化
- timer_button.restart()
    * **タイマー**を動かす
    * 「**再開**」を「**停止**」に、「**リセット**」を無効化
- timer_button.reset()
    * **タイマー**と**指示書表示**の初期化
    * **セレクトボックス**を有効化
    * 「**再開**」を「**開始**」に、「**リセット**」を無効化
    * セリフ・指示表示エリアから`scenario{数字}`のクラスを除去

「停止」ボタンは意図せぬリセットを防ぐ意味合いで設置したため、押しても「次へ」などは有効のままである。
コード例として、`timer_button.start()`を掲載しておく。
```js
this.start = function(){
  sendComm(0, 0);
  $('#select').prop('disabled', true);
  $('#scenario_next').prop('disabled', false);
  timer = setInterval(function(){pass_time++; readTime();}, 1000);
  $('#timer_start').hide();
  $('#timer_stop').show();
  $('#timer_reset').prop('disabled', true);
};
```

#### タイマー関連
画面には、**「開始」が押されてからの時間経過**を表示するタイマーがある。
特にタイマーが必須だったわけではなく、遊びでつけてしまったものである。

ボタン操作と連動するので、`timer_button`のメンバとなっている。
`pass_time`が経過時間で、単位は秒。
`readTime()`を呼び出すと、`pass_time`を**"時:分:秒"のフォーマット**に直した上で表示する。
「開始」または「再開」が押されると`setInterval()`によって`readTime()`が**1秒おきに実行**されるようになる。

また、タイマーが表示される部分は**プログレスバー**(進行状況を示す棒グラフ)であり、`value`に0~1の値を入れることができる。
ここでは、公演の標準的な時間を25分として、進行の目安を確認できるようにした(本番で活用されてはいなかったようだが...)。
```js
var pass_time = 0;
var readTime = function(){
  var hour     = toDoubleDigits(Math.floor(pass_time / 3600));
  var minute   = toDoubleDigits(Math.floor((pass_time - 3600*hour) / 60));
  var second   = toDoubleDigits((pass_time - 3600*hour - 60*minute));
  $('#progress_bar progress').attr('pass_time', hour + ':' + minute + ':' + second);
  var progress = Math.min(pass_time / 1500.0, 1); // 25 minutes
  $('#progress_bar progress').attr('value', progress);
  return;
};
var toDoubleDigits = function(num){return ('0' + num).slice(-2);}; // sliceで時刻要素の0埋め
```

### 指示の送信
`acrab_main.js`に実装がある`getRequest()`と`checkStatus()`を利用する。
しかし、メイン画面と違いユーザが**進む・戻る**の動作をするので、それに対応した。
`scenario`オブジェクトから`index`番目の指示を読み取り、`reverse`がtrue(=「前へ」ボタンがクリックされている)なら真偽値の部分を反転させる。
後は完成した指示を送信するだけだが、前に書いたように同時点灯の問題が出たため、ここでも`each_slice()`した上で送るようにした。

実はこの部分、**グループに対応していない**。`acrab_main.js`の`button.group(obj)`では、「夏の大三角」等のボタンがクリックされると、

1. `ip`からIPアドレスを取得してURLを作成
1. `group[(三文字コード).value]`で`$.each()`を回し、南北判定していずれかの`data`に追加
1. `req`オブジェクトに南北それぞれのデータを入れ、`getRequest()`

という手順によって「夏の大三角」の星座が光るシステムだが、指示の送信`sendComm()`では、

1. `ip`からIPアドレスを取得してURLを作成
1. `getRequest()`

という流れになってしまっているため、折角指示書でグループを指定しても**光らない**。
グループ関連の指示(Wnd等)が来た時には処理を分岐させるなど、何らかの工夫が必要だろう。

なお、画面右に表示されている星座名付きのグリッドは、メイン画面と同じIDにしてあり**オンになったものに色が付く**。
同一ページ内でIDが被るのはHTMLの規格上間違いであるが、`Acrab`ではどちらかが常に非表示になるため不具合は出ないと判断した。
```js
function sendComm(index, reverse){
  var data = $.extend(true, {}, scenario[index].projector);
  if(reverse) $.each(data, function(key){
    data[key] = this == 1 ? 0 : 1;
  });
  $.each(ip, function(){
    address = this + 'setPort/status.json';
    sliced_data = each_slice(data, 5);
    $.each(sliced_data, function(){
      getRequest(address, this).done(function(res){checkStatus(res)});
      sleep_ms(100);
    });
  });
}
```

### 前へ/次へ/スキップボタン
指示の送信は`sendComm()`に番号を渡せば済むので、ここでは**何番目の指示を次に送るべきかを管理**する。
前述の通り、現状を挟んで三つの指示が表示される領域には`scenario{数字}`なるクラスが付与されているので、そこから数字を取り出して利用する。

実装については` goNext()`のコード例を読んで頂くとして、処理の流れのみ解説しておく。

- クラス名から**数字を取得**し、`num`に格納
- クラスを一旦削除し、数字を増やし(減らし)て再追加
- 次のnumが0以下か最終番号を超えるか
    * true: 指示が存在しないので**ボタンを無効化**して**メッセージ表示**
    * false: `#scenario_now`の処理中なら**指示を送信**(スキップの場合は指示を送信しない)
- `#scenario_number`に`#scenario_now`の番号を表示

```js
function goNext(){
  $.each(['scenario_prev', 'scenario_now', 'scenario_next','scenario_skipnext'], function(){
    var num = $('#'+this).get(0).className.match(/\d/g).join('') / 1; // 数字だけ取り出して渡す(型変換しないとうまくいかなかった)
    $('#'+this).removeClass($('#'+this).get(0).className).addClass('scenario' + (num+1));
    if(num+1 > scenario.length){
        if(this == 'scenario_skipnext')
            $('#'+this).html('---').prop('disabled', true);
        else
            $('#'+this).html('(原稿の最後です)').prop('disabled', true);
    } 
    else{
      if(this == 'scenario_now') sendComm(num, 0);
      if(this != 'scenario_skipnext')
          viewScript('#'+this, num);
    }
  });
  $('#scenario_number').html($('#scenario_now').get(0).className.match(/\d/g).join('') + '/' + scenario.length);
}
```
