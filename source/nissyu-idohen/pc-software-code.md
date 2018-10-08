# 日周緯度変(Ogoseの実装解説)
- 書いた人: Kenichi Ito(nichiden_27)
- 更新: Hanaka Satoh(nichiden_28)
- 更新日時: 2018/10/08
- 実行に必要な知識・技能: Windows GUI開発、C#、WPF、Visual Studioの操作
- 難易度: 3/練習・勉強が必要
- 情報の必須度: 3/必要な場合がある

## 概要
[日周緯度変(外部制御アプリ)](pc-software.html)から`Ogose`の実装解説を分離した記事です。

`Ogose`のソースコードを読む、あるいは書き換える際に参考にしてください。

## ファイル構成
`Ogose`のソースファイル等は、`Ogose`フォルダ内に入っている。以下にファイル・ディレクトリ構成の抜粋を示す。
```
Ogose
├── Ogose
│   ├── App.config
│   ├── App.xaml
│   ├── App.xaml.cs
│   ├── MainWindow.xaml
│   ├── MainWindow.xaml.cs
│   ├── NisshuidohenController.cs
│   ├── Ogose.csproj
│   ├── Properties
│   |   └── (省略)
│   ├── bin
│   │   ├── Debug
│   │   │   ├── Ogose.exe
│   |   │   └── (省略)
│   │   └── Release
│   │       ├── Ogose.exe
│   |       └── (省略)
│   ├── main_projector_27_w.png
│   └── obj
│       └── (省略)
└── Ogose.sln
```

一見複雑で身構えてしまうかもしれない。
ただ、`Visual Studio(以下VS)`でプロジェクトを作成すると自動で生成されるファイルがほとんどで、実際に開発者が触るべきファイルは多くない。

`Ogose`直下には`Ogose.sln`がある。これは「ソリューション(開発プロジェクトをまとめたもの)」の状態を管理している。
slnファイルをダブルクリックするか、VS内の読み込みメニューで選択してあげれば`Ogose`の各ファイルを閲覧できる。

`Ogose`の下に更に`Ogose`ディレクトリがあり、この中にソースコードなどが収められている。
このうち、開発で実際に触ったのは`App.xaml` `MainWindow.xaml` `MainWindow.xaml.cs` `NisshuidohenController.cs`の四つのみである。

`Ogose/Ogose/bin/`以下には、ビルドで生成された`.exe`ファイルが格納される。
`Debug`と`Release`は適当に使い分ければいい。exeの他にも様々なファイルが吐き出されるが、基本的には`Ogose.exe`単体で動作する。

以下、ソースコードを簡単に解説する。WPF開発の基本的な知識全てに触れるとは限らないので、よく理解できない部分はググるなどして補完してもらいたい。

## App.xaml
`App.xaml`や`App.xaml.cs`の内容は、GUIのみならずアプリケーション全体に適用される。
何も書かなくても問題ないが、`Ogose`ではコントロールの外見に関する記述をこちらに分離した。[MainWindow.xaml](#mainwindow-xaml)が長くなりすぎないようにするのが目的である。

XAML(ざむる)は、XMLをベースとしたGUIの記述言語である。XMLのタグを用いて階層状に指示を書けるようになっている。
なお、`<>`で囲まれた単位は「タグ」とも「要素」とも言うが、GUIの要素と混同する危険があるので、ここでは「タグ」に統一する。

`<Application>`タグには色々とおまじないが書いてあるが、気にする必要はない。その下の`<Application.Resources>`内からがコードの本番だ。

### ブラシ
```xml
<!--  App.xaml -->
<SolidColorBrush x:Key="WindowBackground" Color="#FF111111"/>
<SolidColorBrush x:Key="ButtonNormalBackground" Color="#AA444444"/>
<SolidColorBrush x:Key="ButtonHoverBackground" Color="#FF334433"/>
<SolidColorBrush x:Key="ButtonNormalForeground" Color="White"/>
<SolidColorBrush x:Key="ButtonDisableBackground" Color="#AA222222"/>
<SolidColorBrush x:Key="ButtonDisableForeground" Color="SlateGray"/>
<SolidColorBrush x:Key="ButtonNormalBorder" Color="#FF707070"/>

<LinearGradientBrush x:Key="TextBoxBorder" EndPoint="0,20" MappingMode="Absolute" StartPoint="0,0">
    <GradientStop Color="#ABADB3" Offset="0.05"/>
    <GradientStop Color="#E2E3EA" Offset="0.07"/>
    <GradientStop Color="#E3E9EF" Offset="1"/>
</LinearGradientBrush>
```
**ブラシ**は、色などのデザインに名前(`x:Key`)をつけて使い回せるようにしたものである。各色の役割が明確になるし、後からの変更も楽なので積極的に利用した。
`SolidColorBrush`は単色のブラシ、`LinearGradientBrush`はグラデーションのブラシである。

配色が気に入らなければ、ここの色指定を変えれば良い。
色は名称で指定しても良いし([色一覧](http://www.atmarkit.co.jp/fdotnet/dotnettips/1071colorname/colorname.html#colorsample))、Webなどでお馴染みの16進数で更に細かく決めることもできる。
ここでは`ARGB`というRGBに加えアルファ値(透過度)も指定する方式で書いているので注意。例えば`#FF111111`なら、不透明で{R,G,B} =　{17,17,17}の色を指す。

### コントロールテンプレート
**コントロールテンプレート**は、コントロール(ボタンやテキストエリアなど)のテンプレートである。
この中にボタンなどの見た目を書いておくと使い回しが効く。今あるコントロールテンプレートとその用途は以下の通り。

- "NormalToggleButton" ... 日周緯度変回転用のトグルボタン
- "ComboBoxToggleButton" ... 接続するシリアルポートを選択するコンボボックス

また、`<ControlTemplate.Triggers>`タグ内で「トリガー」を指定できる。
トリガーは、特定のイベントが起きたら動的にコントロールの見た目を変更する機能だ。
マウスでポイントした時やクリックした時に色が変わると、操作の結果がユーザーに視覚的に伝わる。

```xml
<!--  App.xaml -->
<ControlTemplate.Triggers>
    <Trigger Property="IsMouseOver" Value="true">
        <Setter TargetName="InnerBackground"  Property="Fill" Value="#FF222288" />
    </Trigger>
    <Trigger Property="IsChecked"  Value="true">
        <Setter Property="Content" Value="停止" />
        <Setter TargetName="InnerBackground"  Property="Fill" Value="#FF111144"/>
    </Trigger>
    <Trigger Property="IsEnabled" Value="false">
        <Setter TargetName="Content" Property="TextBlock.Foreground" Value="{StaticResource ButtonDisableForeground}"  />
        <Setter TargetName="InnerBackground" Property="Fill" Value="{StaticResource ButtonDisableBackground}"  />
    </Trigger>
</ControlTemplate.Triggers>
```

例として、`"NormalToggleButton"`のトリガー定義を紹介する。
マウスポインタが乗った時、Checked(ON)状態になった時でそれぞれ"InnerBackground"の色を変更するようになっている。
`Property="IsEnabled"`は、ボタンが有効(=操作できる)かを示しており、これが`false`の時は、文字・背景の色をグレー調にしてクリックできないことをアピールする。

### スタイル
**スタイル**には、要素の外観を定義できる。
前項のコントロールテンプレートに比べ機能が制限され、より個別の要素に対して用いる。

スタイルの適用の仕方はいくつかある。`TargetType`**に要素の種類を入れると、同じ種類の要素全てに適用される**。
以下は`Window`の見た目を指定している例。
```xml
<!--  App.xaml -->
<Style TargetType="Window">
    <Setter Property="Background" Value="{StaticResource WindowBackground}" />
    <Setter Property="Height" Value="600" />
    <Setter Property="MinHeight" Value="600" />
    <Setter Property="Width" Value="700" />
    <Setter Property="MinWidth" Value="700" />
</Style>
```

`<Setter>`タグはプロパティを操作するために使う。`Property`にプロパティの名前、`Value`に値を入れるだけである。
`Value`は実際の値でもいいし、ブラシなど他で定義したリソースを与えてもよい。

`<Setter>`の中には更に様々な機能を持ったタグを入れられる。`<ControlTemplate>`が入っていることもあるし、`<Style.Triggers>`タグでトリガーを設定することもできる。
複雑な使い方は筆者もよく把握していないので、頑張ってググって貰いたい。

もう一つのスタイル適用方法は、`x:Key`**プロパティ**を用いることだ。`<Style>`タグに`x:Key="hogefuga"`のように分かりやすい名前をつけておく。

```xml
<!--  App.xaml -->
<Style x:Key="DiurnalPlusButton" TargetType="ToggleButton" BasedOn="{StaticResource ToggleButton}">
    <Setter Property="Content" Value="日周戻す" />
    <Setter Property="FontSize" Value="18" />
</Style>

<Style x:Key="DiurnalMinusButton" TargetType="ToggleButton" BasedOn="{StaticResource DiurnalPlusButton}">
    <Setter Property="Content" Value="日周進める" />
</Style>
```

そして、適用したいボタンなどに`Style="{StaticResource hogefuga}"`などと指定すれば該当する`x:Key`を持つスタイルが適用される。

```xml
<!--  MainWindow.xaml -->
<ToggleButton x:Name="diurnalPlusButton" Style="{StaticResource DiurnalPlusButton}" Grid.Row="2" Grid.Column="0"
               Command="{x:Static local:MainWindow.diurnalPlusButtonCommand}" />
```
上の`App.xaml`のコードでは、**スタイルの継承**という機能も活用している。
`BasedOn`プロパティに基にしたいスタイルの`x:Key`を指定すると、そのスタイルの中身を引き継いだり、部分的に書き換えたりできる。

例えば、`"DiurnalMinusButton"`スタイルは`"DiurnalPlusButton"`スタイルを継承したので、`FontSize`について再度記述する必要がない。
一方で、ボタンに表示する文字は変更したいので、`Content`を書き換えている。

## MainWindow.xaml
メインのウィンドウの構造を記述する。
といっても`Ogose`には一つしかウィンドウがないので、配置を変えたい場合はこれを編集すればいい。
UIのデザインについてもこの中に書けるが、たいへん長いので[App.xaml](#app-xaml)に移した。

### 編集方法について
ウィンドウの見た目はXAMLのコードだけで自在に操れるが、VSではより便利に、実際の画面をプレビューしながらドラッグ&ドロップで編集することもできる。

![Visual Studioの画面プレビュー編集](_media/mainwindow-xaml.png)

GUIでの編集は手軽で初心者にも扱いやすいが、コードが自動生成されるので手で書くよりも読みにくくなりがちだ。
また、数値を細かく決めたい場合はコードを直接編集した方が早い。
図のように画面プレビューとコードは並べて表示できるので、双方の利点を使い分けるとよかろう。

### グリッド
WPFのレイアウト要素はいくつかあるが、`Ogose`では`<Grid>`タグを使ってレイアウトしている。
**グリッド**は、画面を格子状に分割してその中に要素を配置していくことができる。
いちいち行や列を定義せねばならず面倒だが、サイズを相対的に決められるので、ウィンドウを大きくしたときボタンも拡大されるというメリットがある。

```xml
<!-- MainWindow.xaml -->
<Grid x:Name="MainGrid">
    <Grid.RowDefinitions>
        <RowDefinition Height="1*"/>
        <RowDefinition Height="30"/>
        <RowDefinition Height="40*"/>
        <RowDefinition Height="2*"/>
        <RowDefinition Height="1*"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="1*"/>
        <ColumnDefinition Width="60*"/>
        <ColumnDefinition Width="20*"/>
        <ColumnDefinition Width="20*"/>
        <ColumnDefinition Width="1*"/>
    </Grid.ColumnDefinitions>
    <Grid x:Name="HeaderGrid" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="9*"/>
            <ColumnDefinition Width="1*"/>
            <ColumnDefinition Width="13*"/>
            <ColumnDefinition Width="7*"/>
        </Grid.ColumnDefinitions>
```

上のコード片は、グリッドを定義している例である。
一意の`x:Name`を付けて`<Grid>`を宣言したら、`<Grid.RowDefinitions>`で行を、`<Grid.ColumnDefinitions>`で列を定義する。

#### グリッドの使い方
それぞれの中に行・列を欲しいだけ並べれば良いのだが、**高さや幅の指定**にポイントがある。
数値のみを書くとピクセル数を表すが、`数値*`とすると相対サイズを表せるのだ。
例えば、`Height="1*"`の行と`Height="2*"`の行だけがある場合、グリッドは1:2の比率で分割される。

また、コード例では使っていないが`Auto`を指定すると、中に配置した子要素のサイズに合わせてくれる。
ピクセル指定、相対指定、Auto指定は混ぜて書いても問題ない。
画面プレビューで行や列を分割した場合、サイズが単純な数値にならないので適宜コード側で修正するといいだろう。

**グリッドの中に要素を置く**時は、画面プレビュー上で設置したい場所に動かすだけで良い。
ただし、グリッドは入れ子にすることもでき(コード例では`MainGrid`の下に`HeaderGrid`を入れてある)、意図した階層に置けないことも多々ある。
その場合は、望みの階層に要素の定義をコピペした上で、`Grid.Row`と`Grid.Column`プロパティに何行何列目かを指定する。
両プロパティは**0始まり**なので要注意。`Grid.Row="1" Grid.Column="1"`なら2行2列目だ。

要素が横に長く、**複数の列に渡って配置**したいーそんな時は、`Grid.RowSpan`や`Grid.ColumnSpan`を使おう。
それぞれに指定した数だけ要素が占める場所が下方向・右方向に伸びる。
これは、画面プレビューで操作している時に勝手に追加されていることもあるので、やはりコード側で直してあげよう。

### UI要素
個別のUI要素については実際にコードを見ていただく方が早い。
`Ogose`では`ComboBox`、`ToggleButton`、`RadioButton`、`CheckBox`などを使い分けている。
それぞれの動作を規定するコードについては、[MainWindow.xaml.cs](#mainwindow-xaml-cs)の項で扱う。

少し説明が必要なのは、`RadioButton`についてだ。
**ラジオボタン**というと、
```
◎ 選択肢1
◎ 選択肢2
```
のようなデザインが普通だ。

しかし、`Ogose`では縦に並べたり横に並べたりするので、横の二重丸がなく/普通のボタンと同じ見た目で/全体がクリック可能 である方が都合がよい。
実は、これには複雑なコーディングは必要なく、トグルボタン用のスタイルを適用してやるだけで済む。

```xml
<!--  App.xaml -->
<Style TargetType="RadioButton" BasedOn="{StaticResource ToggleButton}">
```

これは、`RadioButton`クラスが`ToggleButton`クラスを継承しているため、共通のスタイル指定が使えることによる
(参考にした記事: [RadioButtonなToggleButtonを実現する](http://neareal.net/index.php?Programming%2F.NetFramework%2FWPF%2FRadioToggleButton))。

## MainWindow.xaml.cs
`MainWindow.xaml`のコードビハインドである。C#で書かれている。
日電のWindowsアプリケーションは代々C#なので、宗教上やむを得ない事情がなければC#を読み書きできるようになろう。

とはいえ、VSのコード補完(`IntelliSense`)が凄く優秀なので、コードを書いていて苦労することはあまりなさそうだ。
筆者もC#経験はないが、言語使用についてはfor文を少しググったくらいで不便を感じることは少なかった。

コード中にやたら`<summary></summary>`で囲まれたコメントを目にすると思うが、これはVSのドキュメント自動生成機能の推奨XMLタグらしい。
ドキュメントを作るかは別として、面倒でなければこの形式のコメントにして損はなさそうだ。

400行近いコードの全てを解説することはしないので、コードだけでは分かりにくいと思われる項目のみを以下に掲載する。

### コマンド
**コマンド**とは、ユーザの操作を抽象化したものである。
例えば、Wordで編集していてペースト操作をしたいとき、どうするか考えてみよう。
ショートカットキーを知っていれば`Ctrl(Command)`+`V`を叩くだろうし、右クリックしてペーストを選ぶ人もいるだろう。
メニューバーからペーストメニューを選択してもペーストできる。
操作はいろいろだが、結果として呼ばれる処理は同一なのだ。
この仕組みがコマンドで、WPFでは`ICommand`というインターフェースで実現される。

無理にコマンドを使わずともアプリは作れるのだが、`Ogose`のキーボード操作を実装する際、必要に迫られて導入した。
これまでと違い`Ogose`の回転/停止ボタンはトグル式で、色やラベルが状態により変化する。
25までClickイベントを用いる方式では上手く行かなくなったのである(キー操作だと、外観を変えるべきボタンの名称を関数内で取得できないため...だった気がする)。

そこで、`ICommand`を使うようにプログラムを書き直した。
時間がない中でやったので、かなり汚いコードになってしまった。
今後書き換える際はぜひ何とかして欲しい。

#### コマンドの使い方
コマンドは高機能の代わりに難解なので、使い始めるときは[この記事](http://techoh.net/wpf-make-command-in-5steps/)あたりを参考にした。

まず、`RoutedCommand`クラスを宣言する。絶賛コピペなので意味はよく知らない。
`diurnalPlus`は日周を進めるという意味だ。

```c#
/// <summary> RoutedCommand </summary>
public readonly static RoutedCommand diurnalPlusButtonCommand = new RoutedCommand("diurnalPlusButtonCommand", typeof(MainWindow));
```

この状態ではまだコマンドとボタン・処理が結びついていない。
CommandBindingという操作でこれらを紐付けする。これもコピペ。

```c#
/// <summary>
/// MainWindowに必要なコマンドを追加する。コンストラクタで呼び出して下さい
/// </summary>
private void initCommandBindings()
{
    diurnalPlusButton.CommandBindings.Add(new CommandBinding(diurnalPlusButtonCommand, diurnalPlusButtonCommand_Executed, toggleButton_CanExecuted));
    /// (省略)
}
```

これをボタンの数だけ書き連ねる。
`new CommandBinding()`に与えている引数は順に、コマンド・実行する関数・実行可能かを与える関数である。
三番目のコマンド実行可否は、コマンドを実行されては困る時のための仕組みだ。

```c#
/// <summary> 各ボタンが操作できるかどうかを記憶 </summary>
private Dictionary<string, bool> isEnabled = new Dictionary<string, bool>()
{
    {"diurnalPlusButton", true},
    {"diurnalMinusButton", true},
    {"latitudePlusButton", true},
    {"latitudeMinusButton", true}
};
```
``` c#
private void toggleButton_CanExecuted(object sender, CanExecuteRoutedEventArgs e)
{
    e.CanExecute = isEnabled[((ToggleButton)sender).Name];
}
```

上手い方法が全然思いつかなかったので、`isEnabled`という連想配列を作っておいて、呼び出し元ボタンの名前をもとに参照するようにした。
呼び出し元は、引数`sender`に与えられて、`ToggleButton`など元々のクラスに型変換するとプロパティを見たりできる。

さて、`private void initCommandBindings()`をプログラム開始時に実行しなければバインディングが適用されない。
`MainWindow`のコンストラクタ内で呼び出しておく。
```c#
public MainWindow()
{
    InitializeComponent();
    initCommandBindings();
}
```

考えてみれば大したことはしてないので、コンストラクタの中に直接書いてしまっても良かったかもしれない。

あとはXAML側でコマンドを呼び出せるようにするだけである。
`<Window>`タグ内にローカルの名前空間(`xmlns:local="clr-namespace:Ogose"`)がなければ追加しておこう。
各コントロールの`Command`プロパティにコマンドをコピペする。

```xml
<!-- MainWindow.xaml -->
<ToggleButton x:Name="diurnalPlusButton" Style="{StaticResource DiurnalPlusButton}" Grid.Row="2" Grid.Column="0"
               Command="{x:Static local:MainWindow.diurnalPlusButtonCommand}" />
```

これでクリック操作でコマンドが使えるようになる。

#### キー操作でコマンドを実行する(※28日電では誤操作防止のため使用せず)
ここまできたら、キー操作でもコマンドが実行されるようにしたい。
XAMLで`<KeyBinding>`タグを使えば実現できるのだが、なんとこれではボタンが`sender`にならない。
色々調べても対処法が見つからないので、結局キー操作イベントから無理やりコマンドを実行させるしかなかった。

```c#
private void Window_KeyDown(object sender, KeyEventArgs e)
{
    var target = new ToggleButton();
    switch (e.Key)
    {
        case Key.W:
            latitudePlusButtonCommand.Execute("KeyDown", latitudePlusButton);
            break;
        case Key.A:
            diurnalPlusButtonCommand.Execute("KeyDown", diurnalPlusButton);
            break;
        case Key.S:
            latitudeMinusButtonCommand.Execute("KeyDown", latitudeMinusButton);
            break;
        case Key.D:
            diurnalMinusButtonCommand.Execute("KeyDown", diurnalMinusButton);
            break;
    }
```

`(コマンド名).Execute()`メソッドの第一引数は`ExecutedRoutedEventArgs e`の`Parameter`、第二引数は`object sender`として渡される。
結局、`sender`は第二引数に人力で指定した。

`e.Parameter`というのは、仕様では「コマンドに固有の情報を渡す」とされていて、要は自由に使っていいようだ。
キーボード操作によるものかどうか、コマンドの処理で判定するために"KeyDown"という文字列(勝手に決めた)を渡している。

※28代でメモ欄を設置したことにより、キー操作による誤操作の可能性が高まったことと、皆結局マウスで操作していることからいったん`MainWindow.xaml`の`Keydown`イベントを削除し、キー操作でのコマンド実行を無効にした。

#### コマンドで呼ばれる処理
最後に、CommandBindingでコマンドと紐付けた関数について書く。
日周を進めるボタンのものは以下のようになっている。

```c#
private void diurnalPlusButtonCommand_Executed(object sender, ExecutedRoutedEventArgs e)
{
    if (e.Parameter != null && e.Parameter.ToString() == "KeyDown")
    {
        ((ToggleButton)sender).IsChecked = !((ToggleButton)sender).IsChecked;
    }
    if (sender as ToggleButton != null && ((ToggleButton)sender).IsChecked == false)
    {
        emitCommand(nisshuidohenController.RotateDiurnalBySpeed(0));
    }
    else
    {
        emitCommand(nisshuidohenController.RotateDiurnalBySpeed(diurnal_speed));
    }
    if (sender as ToggleButton != null) toggleOppositeButton((ToggleButton)sender);
}
```

どうしてこのような汚いコードになったのか弁解しておこう。
この関数は、三箇所から呼び出される可能性がある。

まず、対応するボタンがクリックされた場合。
クリックした時点でボタンの`IsChecked`プロパティが反転するので、falseならモータを停止させ、trueなら動かせば良い。

ところが、キー操作イベントから呼ばれた場合、ボタンの状態は変わらない。
最初のif文で、`e.Parameter.ToString() == "KeyDown"`であるときだけ、ボタンの`IsChecked`を反転させることで対応した。

もう一つの可能性は、速度を切り替えたときだ。
日周の速度を管理している`diurnalRadioButton`がクリックされたとき実行されるコードを見てみよう。

```c#
private void diurnalRadioButton_Checked(object sender, RoutedEventArgs e)
{
    var radioButton = (RadioButton)sender;
    if (radioButton.Name == "diurnalRadioButton1") diurnal_speed = SPEED_DIURNAL["very_high"];
    else if (radioButton.Name == "diurnalRadioButton2") diurnal_speed = SPEED_DIURNAL["high"];
    else if (radioButton.Name == "diurnalRadioButton3") diurnal_speed = SPEED_DIURNAL["low"];
    else if (radioButton.Name == "diurnalRadioButton4") diurnal_speed = SPEED_DIURNAL["very_low"];

    if (diurnalPlusButton.IsChecked == true)
        diurnalPlusButtonCommand.Execute(null, diurnalPlusButton);
    if (diurnalMinusButton.IsChecked == true)
        diurnalMinusButtonCommand.Execute(null, diurnalMinusButton);
}
```

前半は、`sender`がどの項目かによって速度を変更しているだけなので問題ないだろう。
後半で、「日周進める」か「日周戻す」がCheckedになっていれば、新しい設定をさいたまに送るためコマンドを実行している。

このときボタンの`IsChecked`プロパティはすでにtrueなので、二重に変更されないよう`e.Parameter`をnullとしている。
だが、考えてみればさいたまと通信さえすればいいので、**ボタンなど経由せず直接**`emitCommand()`**(さいたまにコマンドを送る関数)を呼べばいいだけである。**

総じて、コマンドを使うことにこだわりすぎて酷いコードになってしまった。
バグの原因になっている可能性もあるので、後任の方は綺麗に書き直してやって頂きたい。

### シリアル通信
`MainWindow.xaml.cs`のうちシリアル通信に関する記述の大部分は、24の`Fujisawa`から受け継いでいる。
この項では、通信を行うためのコードを読み、必要に応じて解説を加える。

#### ポート一覧の取得
```c#
/// <summary>
/// シリアルポート名を取得し前回接続したものがあればそれを使用 ボーレートの設定
/// </summary>
/// <param name="ports[]">取得したシリアルポート名の配列</param>
/// <param name="port">ports[]の要素</param>
private void Window_Loaded(object sender, RoutedEventArgs e)
{
    var ports = SerialPort.GetPortNames();
    foreach (var port in ports)
    {
        portComboBox.Items.Add(new SerialPortItem { Name = port });
    }
    if (portComboBox.Items.Count > 0)
    {
        if (ports.Contains(Settings.Default.LastConnectedPort))
            portComboBox.SelectedIndex = Array.IndexOf(ports, Settings.Default.LastConnectedPort);
        else
            portComboBox.SelectedIndex = 0;
    }
    serialPort = new SerialPort
    {
        BaudRate = 2400
    };
}
```

`Window_Loaded`は、ウィンドウが描画されるタイミングで実行される。  
処理としては、シリアルポート一覧を取得して`portComboBox`に候補として追加し、さらに前回の接続先と照合するというものだ。
また、`SerialPort`クラスのオブジェクト`serialPort`を宣言し、ボーレートを2400に設定している。

foreach文の中で使用している`SerialPortItem`は自作クラスで、`ToString()`をオーバーライドしている。
何の為のものかは理解していないので、興味があればソースコードを確認してほしい。

#### ポートへの接続
接続ボタンがクリックされると、`ConnectButton_IsCheckedChanged()`が呼ばれる。
その中身はこうだ。

```c#
    /// <summary>
    /// PortComboBoxが空でなくConnectButtonがチェックされている時にシリアルポートの開閉を行う シリアルポートの開閉時に誤動作が発生しないよう回避している
    /// </summary>
    private void ConnectButton_IsCheckedChanged(object sender, RoutedEventArgs e)
    {
        var item = portComboBox.SelectedItem as SerialPortItem;
        if (item != null && ConnectButton.IsChecked.HasValue)
        {
            bool connecting = ConnectButton.IsChecked.Value;
            ConnectButton.Checked -= ConnectButton_IsCheckedChanged;
            ConnectButton.Unchecked -= ConnectButton_IsCheckedChanged;
            ConnectButton.IsChecked = null;

            if (serialPort.IsOpen) serialPort.Close();
            if (connecting)
            {
                serialPort.PortName = item.Name;
                try
                {
                    serialPort.WriteTimeout = 500;
                    serialPort.Open();
                }
                catch (IOException ex)
                {
                    ConnectButton.IsChecked = false;
                    MessageBox.Show(ex.ToString(), ex.GetType().Name);
                    return;
                }
                catch (UnauthorizedAccessException ex)
                {
                    ConnectButton.IsChecked = false;
                    MessageBox.Show(ex.ToString(), ex.GetType().Name);
                    return;
                }
                Settings.Default.LastConnectedPort = item.Name;
                Settings.Default.Save();
            }

            ConnectButton.IsChecked = connecting;
            ConnectButton.Checked += ConnectButton_IsCheckedChanged;
            ConnectButton.Unchecked += ConnectButton_IsCheckedChanged;
            portComboBox.IsEnabled = !connecting;
        }
        else
        {
            ConnectButton.IsChecked = false;
        }
    }
```

かなり長いが、順番に見ていこう。
最初のif文はポートが選択されているかチェックしているだけだ。
`bool connecting`はポートを開くのか閉じるのかの分岐に使われている。
後はtry-catch文でポートを開き、エラーが出れば警告を出すのだが、このブロックの上下に変な記述がある。

```c#
ConnectButton.Checked -= ConnectButton_IsCheckedChanged;
ConnectButton.Unchecked -= ConnectButton_IsCheckedChanged;
ConnectButton.IsChecked = null;
/// (省略)
ConnectButton.IsChecked = connecting;
ConnectButton.Checked += ConnectButton_IsCheckedChanged;
ConnectButton.Unchecked += ConnectButton_IsCheckedChanged;
```

これはおそらくコメントの言う「シリアルポートの開閉時に誤動作が発生しないよう回避している」部分であろう。
`MainWindow.xaml`の、`ConnectButton`に関する部分を見てみよう。

```xml
<!-- MainWindow.xaml -->
<ToggleButton x:Name="ConnectButton" Checked="ConnectButton_IsCheckedChanged" Unchecked="ConnectButton_IsCheckedChanged" Margin="0">
```

`Checked`と`Unchecked`は、いずれもボタンがクリックされた時に発生するイベントだ。
`ConnectButton.Checked -= ConnectButton_IsCheckedChanged;`などとしておくことで、ポートへの接続を試行している間ボタンのクリックを無効化しているようだ。
このコードを削除した状態でボタンを連打しても特に問題はなかったので効果のほどは分からないが、あっても害にはならないだろう。


#### ポート一覧の更新
ポート一覧のコンボボックスは、開くたびにシリアルポートを取得し直している。
`portComboBox_DropDownOpened()`に処理が書かれているが、`Window_Loaded()`と同じようなことをしているだけなので省略する。

#### コマンド送信
`emitCommand()`は、コマンド文字列を与えて実行すると接続しているポートに送信してくれる。
`serialPort.IsOpen`がfalseの時は、警告とともにコマンド文字列をMessageBoxに表示する。

```c#
/// <summary>
/// シリアルポートが開いている時にコマンドcmdをシリアルポートに書き込み閉じている時はMassageBoxを表示する
/// </summary>
/// <param name="cmd"></param>
private void emitCommand(string cmd)
{
    if (serialPort.IsOpen)
    {
        var bytes = Encoding.ASCII.GetBytes(cmd);
        serialPort.RtsEnable = true;
        serialPort.Write(bytes, 0, bytes.Length);
        Thread.Sleep(100);
        serialPort.RtsEnable = false;
    }

    else
    {
        MessageBox.Show("Error: コントローラと接続して下さい\ncommand: "+ cmd, "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
    }
}
```

### 公演モード(誤操作防止モード)
`checkBox2`は公演モードのON/OFFを管理している。
公演モードは、日周を進める以外の機能を制限して誤操作を防ぐ為のものだ。
一応28で目立ったバグは修正したつもりだが、何らかの不具合が確認された場合は適宜修正してもらいたい。

```c#
private void checkBox2_Checked(object sender, RoutedEventArgs e)
        {
            var result = new MessageBoxResult();
            result = MessageBox.Show("公演モードに切り替えます。\n日周を進める以外の動作はロックされます。よろしいですか？", "Changing Mode", MessageBoxButton.YesNo);
            
            if(result == MessageBoxResult.No)
            {
                checkBox2.IsChecked = false;
                return;
            }
            isPerfMode = true;
            List<string> keyList = new List<string>(isEnabled.Keys); // isEnabled.Keysを直接見に行くとループで書き換えてるので実行時エラーになる
            foreach (string key in keyList)
            {
                if(key != "diurnalMinusButton") isEnabled[key] = !isPerfMode;
            }
            latitudeRadioButton1.IsEnabled = latitudeRadioButton2.IsEnabled = latitudeRadioButton3.IsEnabled = latitudeRadioButton4.IsEnabled = !isPerfMode;
            notepadCombobox.IsEnabled = Savebutton1.IsEnabled = !isPerfMode;
            textBox1.Focusable = !isPerfMode; 
        }

        private void checkBox2_Unchecked(object sender, RoutedEventArgs e)
        {
            var result = new MessageBoxResult();
            result = MessageBox.Show("公演モードを終了します。", "Finish PerfMode", MessageBoxButton.OK);

            isPerfMode = false;
            List<string> keyList = new List<string>(isEnabled.Keys); // isEnabled.Keysを直接見に行くとループで書き換えてるので実行時エラーになる
            foreach (string key in keyList)
            {
                if (key != "diurnalMinusButton") isEnabled[key] = !isPerfMode;
            }
            latitudeRadioButton1.IsEnabled = latitudeRadioButton2.IsEnabled = latitudeRadioButton3.IsEnabled = latitudeRadioButton4.IsEnabled = !isPerfMode;
            notepadCombobox.IsEnabled = Savebutton1.IsEnabled = !isPerfMode;
            textBox1.Focusable = !isPerfMode; 
        }
```

他の関数等で公演モードかどうかいちいち判定する必要が出てきたので、`isPerfMode`というbool値に記録するようにした。
たいへん紛らわしいが、`diurnalMinusButton`が「日周進める」ボタンである。
実機で運用した際に、かごしいの実際の動きを合わせてラベルだけ交換したため逆になっている。
28でもかごしいに合わせ何度かラベル交換したので、29のかごしいの動きではそれぞれのボタンを押したときにどのような動きをするのかしっかりと確認し、変更してほしい。

### メモ帳機能
`notepadCombobox_DropDownOpened`は、メモ帳を読み込むときに使われる。コンボボックスを開いた時も閉じたときもこの処理が行われるようになっているが、  
この仕様のせいで妙に重い等の不具合がもしあれば修正したほうがいいのかもしれない。  
メモ帳に加えた変更の保存は、`Savebutton1_Click`の方で行っている。

```c#
private void notepadCombobox_DropDownOpened(object sender, EventArgs e)
        {
            var item = notepadCombobox.SelectedItem;
            notepadCombobox.SelectedIndex = -1;
            notepadCombobox.Items.Clear();

            string[] files = Directory.GetFiles(
                    @"..\..\WorkInstructions", "*.txt", SearchOption.AllDirectories);
            Array.Sort(files);

            foreach (var file in files)
                notepadCombobox.Items.Add(file);

            if (item != null)
            {
                textblock1.Text = Path.GetFileName(item.ToString());
                notepadCombobox.SelectedIndex = Array.IndexOf(files, item.ToString());
                using (FileStream fs = new FileStream(item.ToString(), FileMode.Open, FileAccess.ReadWrite))
                {
                    using (StreamReader sr = new StreamReader(fs, Encoding.GetEncoding("shift_jis"), true))
                    {
                        try
                        {
                            textBox1.Text = sr.ReadToEnd();
                        }
                        catch (Exception ex)
                        {
                            MessageBox.Show(ex.Message);
                        }
                    }

                }
            }
        }
```

構文は[こちらのリンク](https://divakk.co.jp/aoyagi/csharp_tips_using.html)を見て書いた部分が大きい。
読み込むファイルについては、`Directory.GetFiles`を使って`WorkInstructions`ディレクトリ内の.txtファイルを読み込むようにしている…のだが、  
そのファイルのパスがそのままコンボボックスに表示されてしまうため見栄えが悪い。28日電の知識ではどうにもならなかったが、修正できる人がいれば修正してほしいところだ。

## NisshuidohenController.cs
さいたまに送るコマンド文字列を生成するための`NisshuidohenController`クラスが実装されている。
27では、24が書いたものをほぼそのまま利用した。
一点のみ、日周・緯度のギヤ比の換算もこちらでやってしまうように変更した。
これで、クラスの外側からはかごしいを回したい角速度(1 deg/sなど)を指定すればいいようになった。

使うだけなら`RotateDiurnalBySpeed()`や`RotateLatitudeBySpeed()`をブラックボックスとして利用するだけでいいだろう。
ただし、23や25が使っていた角度指定メソッドは残してあるだけで一切触っていないので、使いたい場合はしっかりデバッグしてほしい。
