desc "This task is called by the Heroku scheduler add-on"
task :update_feed => :environment do
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  # 使用したxmlデータ（毎日朝6時更新）：以下URLを入力すれば見ることができます。
  url  = "https://www.drk7.jp/weather/xml/13.xml"
  # xmlデータをパース（利用しやすいように整形）
  xml  = open( url ).read.toutf8
  doc = REXML::Document.new(xml)
  # パスの共通部分を変数化（area[4]は「東京地方」を指定している）
  xpath = 'weatherforecast/pref/area[4]/info/rainfallchance/'
  # 6時〜12時の降水確率（以下同様）
  per06to12 = doc.elements[xpath + 'period[2]'].text
  per12to18 = doc.elements[xpath + 'period[3]'].text
  per18to24 = doc.elements[xpath + 'period[4]'].text
  # メッセージを発信する降水確率の下限値の設定
  min_per = 30
  if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
    word1 =
      [
      "おはよ〜。おやすみ〜。(眠い)",
      "おはよ。しかし寝足りん!!!",
      "おはざ〜す。今日は朝活をしようかな!!!",
      "グッもーにん!エビバデー!",
      "朝がやってきたのだ！",
      "はろ〜。朝から天丼食いたいよね。",
      "おは。朝マック行きたい。",
      "Hello, world.",
      "おはぴ！今日はなんだかギャルになりたい。ｲｴｲ!"
      ].sample
    word2 =
      [
      "今日も1日頑張りましょ！",
      "雨降らなかったとしても責めないでくれ",
      "雨ニモマケズ、風ニモマケズ！ステーキ食べたい！",
      "晴れると信じるのも手だ。",
      "信じるかは自分次第だけどね。",
      "天気なんか予測不可能だぜ！"
      ].sample
    # 降水確率によってメッセージを変更する値の設定
    mid_per = 50
    if per06to12.to_i >= mid_per || per12to18.to_i >= mid_per || per18to24.to_i >= mid_per
      word3 =
        [
        "[!!大悲報!!]今日雨降りそうですう〜。",
        "実は今日雨降りそうなんじゃ。傘忘れるべからず!!!",
        "今日雨に一発やられそうだぞ。傘を持っていけ。",
        "傘忘れるな！！！",
        "本日雨降りそう！傘持ってくか〜。"
        ].sample
    else
      word3 = "今日はワンチャン雨降るかも！一応雨具の準備を。"
    end
    # 発信するメッセージの設定
    push = "#{word1}\n#{word3}\n今日の東京の降水確率はこんな感じだお。\n　　  6〜12時　#{per06to12}％\n　　12〜18時　#{per12to18}％\n　　18〜24時　#{per18to24}％\n#{word2}"
    # メッセージの発信先idを配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
    user_ids = User.all.pluck(:line_id)
    message = {
      type: 'text',
      text: push
    }
    response = client.multicast(user_ids, message)
  end
  "OK"
end
