class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    events = client.parse_events_from(body)
    events.each { |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 30
          case input
            # 「明日」or「あした」というワードが含まれる場合
          when /.*(明日|あした).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "
                明日の天気だね！\n
                明日は雨降りそうだよ...。\n
                今のところ降水確率はこんな感じ\n
                6〜12時 #{per06to12}％\n
                12〜18時 #{per12to18}％\n
                18〜24時 #{per18to24}％\n
                また明日の朝の最新の天気予報で雨が降りそうだったら教えるでぃ！
                "
            else
              push =
                "
                明日の天気だね!\n
                明日は雨が降らない予定だよ!いいねいいね。\n
                もし雨の予報に変わったら、明日の朝に教えるでぃ！
                "
            end


          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気だね!\n明後日は雨が降りそうなんだ…\n今のところの降水確率はこんな感じ。\n 6時〜12時 #{per06to12}％\n12時〜18時 #{per12to18}％\n18〜24時 #{per18to24}％\n当日の朝に雨が降りそうだったらまた教えるからね！\nホウレンソウ!"
            else
              push =
                "
                明後日の天気かな？\n
                今のところ明後日は雨降らなそう!!!ｻｲｺｳ!\n
                また当日の朝の最新の天気予報で雨が降りそうだったら教えるからね!\n
                待っててくれよな!
                "
            end


          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
            push =
              "
              ありがとう!!!\n
              褒められても嬉しくねえぞ^^
              "


          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "
              おはこんばんにちは。\n
              声をかけてくれてありがとう\n
              今日があなたにとっていい日になりますように(^^)"


          # 上記に登録している単語以外が送信された時
          else
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              word =
                [
                "雨だけど元気出していこう！",
                "雨は萎えるけどなんとかがんばろ〜。",
                "雨を操れるBOTにﾅﾘﾀｲ"
                ].sample
              push =
                "
                よくわからないから、今日の天気を伝えるｿﾞ\n
                今日は雨が降りそうだから傘があった方がいいかもしれぬ。\n
                6〜12時 #{per06to12}％\n
                12〜18時 #{per12to18}％\n
                18〜24時 #{per18to24}％\n
                #{word}
                "
            else
              word =
                [
                "雨降らない!ﾅｲｽ!!!",
                "天気が良いと気分上っちゃううう!",
                "今日はお寿司食べちゃおっかな!",
                "まあ、雨が降らないという確証はないんだけどね"
                ].sample
              push =
                "
                今日の天気？\n
                [!朗報!]雨降らなそう!\n
                #{word}
                "
            end
          end

        # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "文字をplease!!!それ以外はわからにゃい。"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)


        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）


      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end

    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end
