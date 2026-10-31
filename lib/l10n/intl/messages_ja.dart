// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ja';

  static String m0(count, skipped) => "${count}件を追加、${skipped}件は既存のためスキップ";

  static String m1(detail) => "データを消去できませんでした：${detail}";

  static String m2(code) =>
      "Windows が iPingCore.exe の実行を拒否しました（エラー ${code}）。スマート アプリ コントロールや AppLocker などのアプリ制御ポリシーは未署名のプログラムをブロックします。ポリシーで iPing を許可するか、ポリシーを無効にしてから再試行してください。";

  static String m3(name) =>
      "アプリの起動が2回連続で完了しませんでした。クラッシュループを断ち切るため、プロファイル ${name} の選択を解除し、今回の自動セットアップをスキップしました。いつでも選択し直せます。";

  static String m4(url) => "${url} からプロファイルを作成しますか？";

  static String m5(count, label) =>
      "${Intl.plural(count, other: 'カスタム設定はサブルールに対応していないため、SUB-RULE ルール ${label} 件を破棄しました')}";

  static String m6(message) => "コアがこのプロキシを解析できません：${message}";

  static String m7(proxy, target) =>
      "${proxy} は ${target} 経由で接続しますが、${target} から再び ${proxy} に戻るため、ループになります";

  static String m8(name) => "名前 ${name} は他のプロキシまたはプロキシグループで使用されています";

  static String m9(path) => "プロキシグループが循環参照しています：${path}";

  static String m10(name) =>
      "空グループのフォールバックはプロキシである必要がありますが、${name} は存在しないかプロキシグループです";

  static String m11(name, message) => "${name}は有効な正規表現ではありません：${message}";

  static String m12(name) => "ダイヤラープロキシ ${name} が存在しません";

  static String m13(names) => "次のプロキシプロバイダーは存在しません：${names}";

  static String m14(names) => "次のプロキシまたはポリシーは存在しません：${names}";

  static String m15(name) => "${name} は組み込みポリシー名のため使用できません";

  static String m16(count) => "${count} 件に問題があり、プロファイルの適用に失敗する可能性があります";

  static String m17(count) => "${count} 日前";

  static String m18(count) => "${count} 日前";

  static String m19(label) => "選択した${label}を削除してもよろしいですか？";

  static String m20(label) => "この${label}を削除してもよろしいですか？";

  static String m21(label) => "${label}の詳細";

  static String m22(name) => "${name} 経由の接続が使用元のプロキシに戻るため、接続を中止しました";

  static String m23(label) => "${label}は空にできません";

  static String m24(label) => "${label}はすでに存在します";

  static String m25(count) => "${count} 件が失敗しました";

  static String m26(label, message) => "${label}：${message}";

  static String m27(name) => "${name} はすでに最新です";

  static String m28(name) => "${name} を更新しました";

  static String m29(count) => "${count} 個";

  static String m30(count) => "${count} 件タイムアウト";

  static String m31(action) => "「${action}」で使用中です。保存するとこちらに移動します。";

  static String m32(modifiers) => "${modifiers} のいずれかを含めてください";

  static String m33(count) => "${count} 時間前";

  static String m34(count) => "${count} 時間前";

  static String m35(target) => "${target} は無効なポリシーです";

  static String m36(proxyName) => "${proxyName} は無効なプロキシです";

  static String m37(providerName) => "${providerName} は無効なプロキシプロバイダーです";

  static String m38(ruleSet) => "${ruleSet} は無効なルールセットです";

  static String m39(name) => "「${name}」の設定値が無効です。";

  static String m40(subRule) => "${subRule} は無効な SUB_RULE です";

  static String m41(siteName) =>
      "${siteName} サイトでメール、Google、パスキーを使ってログインすると、サブスクリプションを自動的に読み込みます。";

  static String m42(count) => "クリア（${count}）";

  static String m43(count) => "数量は 1 から ${count} までにしてください。";

  static String m44(price) => "${price}/月";

  static String m45(count) => "${count} か月";

  static String m46(count) => "${count} 件の地域";

  static String m47(count) => "在庫 ${count}";

  static String m48(count) => "利用可能なノード：${count}";

  static String m49(fee) => "手数料 ${fee}";

  static String m50(count, cost, shortfall) =>
      "7 日以内に ${count} 件が自動更新され、約 ${cost} かかります。${shortfall} 以上チャージしてください。";

  static String m51(host) => "システム DNS · ${host}";

  static String m52(amount) => "${amount} 上乗せ";

  static String m53(amount) => "${amount} 以上";

  static String m54(percent) => "${percent}% 上乗せ";

  static String m55(amount) => "${amount} 以下";

  static String m56(amount) => "${amount} 以上の金額を入力してください。";

  static String m57(amount) => "${amount} ボーナス";

  static String m58(amount) => "最低 ${amount}";

  static String m59(count) => "${count} 件のリスンアドレスをコピーしました";

  static String m60(count) => "${count} 件のトンネルを一括更新しました";

  static String m61(count) => "${count} 件選択中";

  static String m62(count) => "${count} 件をコピーしました";

  static String m63(address, count) => "${address} +${count}";

  static String m64(rate) => "倍率 ${rate}";

  static String m65(count) => "${count} 本のトンネルが 3 日以内に期限切れになります";

  static String m66(count) => "${count} 本のトンネルのトラフィックが残りわずかです";

  static String m67(price) => "更新すると残高から ${price} が引き落とされます。";

  static String m68(used, quota) => "${used} / ${quota}";

  static String m69(count) => "トンネル ${count} 件";

  static String m70(version) => "バージョン ${version} が利用可能です。今すぐ、または後で更新できます。";

  static String m71(id) => "ユーザー ID ${id}";

  static String m72(version) => "バージョン ${version}";

  static String m73(siteName) => "${siteName} へようこそ";

  static String m74(count) => "${count} 件";

  static String m75(line, message) => "${line}行目：${message}";

  static String m76(appName) =>
      "1. システム設定 > プライバシーとセキュリティ を開く\n2. 位置情報サービス を選択\n3. リストで ${appName} を見つけてチェックを入れる\n\n設定が完了したらアプリに戻ると、通常どおり使用できます。ご協力ありがとうございます。";

  static String m77(label, max) => "${label}は最大${max}文字です";

  static String m78(size) => "${size} を解放しました";

  static String m79(count) => "${count} 分前";

  static String m80(count) => "${count} 分前";

  static String m81(count) => "${count} か月前";

  static String m82(count) => "${count} か月前";

  static String m83(code) =>
      "サーバーがアクセスを拒否しました（HTTP ${code}）。リンクの期限切れか、認証情報が誤っている可能性があります";

  static String m84(code) => "サーバーがリクエストを拒否しました（HTTP ${code}）";

  static String m85(code) =>
      "このアドレスには何も見つかりませんでした（HTTP ${code}）。URL が正しいか確認してください";

  static String m86(detail) => "ネットワークリクエストに失敗しました：${detail}";

  static String m87(code) => "サーバーで問題が発生しました（HTTP ${code}）。しばらくしてから再試行してください";

  static String m88(label) => "${label}はまだありません";

  static String m89(label, min, max) => "${label}は${min}から${max}の範囲で指定してください";

  static String m90(label) => "${label}は数値である必要があります";

  static String m91(label) => "${label} は 1024〜49151 の範囲で指定してください";

  static String m92(port) => "ポート ${port}";

  static String m93(days) => "残り ${days} 日";

  static String m94(date, days) => "${date} に期限切れ、残り ${days} 日";

  static String m95(time) => "${time}に更新";

  static String m96(label, profiles) =>
      "${label} は ${profiles} でまだ使用されており、削除するとそれらが正常に動作しなくなります。削除してもよろしいですか？";

  static String m97(count, label) =>
      "${Intl.plural(count, other: 'プロキシ ${label} 件')}";

  static String m98(name, count) => "${name} など${count}件のプロキシ";

  static String m99(removed) =>
      "次のプロキシが削除されます：${removed}。名前を変えた行は新しいプロキシとして扱われ、削除されたプロキシを参照するカスタムプロファイルでは見つからないと表示されます。適用しますか？";

  static String m100(removed, added) =>
      "次のプロキシが削除されます：${removed}。次のプロキシが追加されます：${added}。名前を変えた行は新しいプロキシとして扱われ、削除されたプロキシを参照するカスタムプロファイルでは見つからないと表示されます。適用しますか？";

  static String m101(label) =>
      "${label} はこのプロファイルのルール、プロキシグループ、ダイヤラープロキシ、DNS または NTP からまだ参照されており、削除するとそれらの参照は無効になります。削除してもよろしいですか？";

  static String m102(count, label) =>
      "${Intl.plural(count, other: 'プロキシグループ ${label} 件')}";

  static String m103(count, label) =>
      "${Intl.plural(count, other: 'ルール ${label} 件')}";

  static String m104(appName) => "${appName}（セーフモード）";

  static String m105(count) => "${count} 秒";

  static String m106(count) => "${count} 件が有効";

  static String m107(count) => "${count} 件に問題";

  static String m108(time) => "${time} に検査";

  static String m109(count) => "設定 ${count} 件";

  static String m110(link) => "${link} からプロキシを読み取れませんでした";

  static String m111(label) => "${label}は1項目のみ指定できます";

  static String m112(value) => "ピーク ${value}";

  static String m113(value) => "累計 ${value}";

  static String m114(label) => "${label}はURLである必要があります";

  static String m115(count) => "${count} 年前";

  static String m116(count) => "${count} 年前";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("アプリについて"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPNを経由します",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "アクセス制御では、プロキシを利用するアプリを選びます。",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "アプリアクセス制御は無効です",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリはVPNから除外されます",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("アクセス制御の設定"),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("すべての遅延をテスト"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("ダイレクトモード"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("グローバルモード"),
    "actionMode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("ルールモード"),
    "actionStart": MessageLookupByLibrary.simpleMessage("開始/停止"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage("プロファイルを更新"),
    "actionView": MessageLookupByLibrary.simpleMessage("表示/非表示"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("プロキシを追加"),
    "addFilters": MessageLookupByLibrary.simpleMessage("フィルターを追加"),
    "addNodes": MessageLookupByLibrary.simpleMessage("ノードを追加"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage("上書き項目を追加"),
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイルを追加"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("設定項目を追加"),
    "addSsid": MessageLookupByLibrary.simpleMessage("SSIDを追加"),
    "addedRules": MessageLookupByLibrary.simpleMessage("追加ルール"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("追加パラメータ"),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("名前のプレフィックス"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("名前のサフィックス"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAVサーバーのアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "有効なWebDAVアドレスを入力してください",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("詳細設定"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "詳細設定には、ネットワーク、DNS、追加ルール、スクリプトがあります。",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage("暗号化されたプロファイル"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("age 秘密鍵"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "このプロファイルは age で暗号化されており、復号には age 秘密鍵が必要です",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("同意する"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "参照されているすべてのプロキシ",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "参照されているすべてのプロキシプロバイダー",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("アプリによるVPNバイパスを許可"),
    "allowLan": MessageLookupByLibrary.simpleMessage("LANプロキシ"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("許可する IP"),
    "answers": MessageLookupByLibrary.simpleMessage("応答"),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("アプリアイコンのデザイン"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("ローカルプロキシがありません"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを追加"),
    "applyResources": MessageLookupByLibrary.simpleMessage("現在のプロファイルにリソースを適用"),
    "authentication": MessageLookupByLibrary.simpleMessage("認証"),
    "authenticationDesc": MessageLookupByLibrary.simpleMessage(
      "認証を有効にすると、ローカルプロキシポートの利用にユーザー名とパスワードが必要になります。",
    ),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "認証が有効な間、システムプロキシは適用されません。",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("許可"),
    "authorized": MessageLookupByLibrary.simpleMessage("許可済み"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("更新の自動チェック"),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動的に閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシを切り替えると、既存の接続を自動的に閉じます。",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("自動で含める"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "自動実行はアプリを開いたときにプロキシを開始します。",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを自動設定"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "back": MessageLookupByLibrary.simpleMessage("戻る"),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "このバックアップは新しいバージョンのアプリで作成されています。アプリを更新してから復元してください",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップが完了しました"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基本情報"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基本ポリシー"),
    "batchAdd": MessageLookupByLibrary.simpleMessage("一括追加"),
    "batchImport": MessageLookupByLibrary.simpleMessage("一括インポート"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1つのリンクを入力してください",
    ),
    "batchListInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1項目、またはカンマ区切りで入力してください",
    ),
    "batchMapInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1件、キーと値はスペースで区切ってください",
    ),
    "batchPreviewTip": m0,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "1行に1つのURLを入力してください",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "電池の最適化を無視すると、アプリがバックグラウンドで動作し続けます。",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("連携"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "blockConnection": MessageLookupByLibrary.simpleMessage("接続をブロック"),
    "brightness": MessageLookupByLibrary.simpleMessage("明度"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("除外ドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "除外ドメインはシステムプロキシが有効な場合のみ適用されます。",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "プライベートアドレスをバイパス",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "プライベートアドレスをバイパスすると、LAN・ループバック・マルチキャストのアドレスは TUN を通りません。",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("キャッシュ"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("キャッシュアルゴリズム"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("キャッシュサイズ"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "QRコードをスキャンするには、システム設定でカメラへのアクセスを許可するか、アルバムからQRコード画像を選択してください。",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "カメラの権限が必要です",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage("カメラを使用できません"),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("すべて選択解除"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("保存できません"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "プロキシの切り替えに失敗したため、前回の選択に戻しました",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("破壊的変更"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("新機能"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("不具合修正"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("パフォーマンス"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("取り消し"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("TLS証明書を検証"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "TLS 証明書の検証を無効にすると、サブスクリプションとバックアップが中間者攻撃にさらされます。",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("すでに最新バージョンです"),
    "cipher": MessageLookupByLibrary.simpleMessage("暗号方式"),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "すべてのプロファイル、設定、ローカルデータを削除してアプリを終了します。もう一度開くと最初から始められます。",
    ),
    "clearDataFailed": m1,
    "clearSearch": MessageLookupByLibrary.simpleMessage("検索をクリア"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "クライアントフィンガープリント",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードへエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "クリップボードにコピーできませんでした。選択範囲が大きすぎる可能性があります",
    ),
    "close": MessageLookupByLibrary.simpleMessage("閉じる"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("接続を閉じる"),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("配色スタイル"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compact": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "confirm": MessageLookupByLibrary.simpleMessage("OK"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "すべてのデータを消去してもよろしいですか？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "このプロキシグループを削除してもよろしいですか？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "現在のウィンドウを閉じてもよろしいですか？",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "コアを強制クラッシュさせてもよろしいですか？",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage("輻輳制御"),
    "congestionController": MessageLookupByLibrary.simpleMessage("TCP 輻輳制御"),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 輻輳制御は mips スタックでのみ有効です。",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "connecting": MessageLookupByLibrary.simpleMessage("接続中…"),
    "connection": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("接続統計"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "ライブ接続、最近のリクエスト、DNS クエリ",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続状態："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容は空にできません"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "グローバル追加ルールを管理",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピーしました"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "coreBlockedByPolicyTip": m2,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows のスマート アプリ コントロールが、署名されていない iPingCore.exe をブロックしました。Windows セキュリティ → アプリとブラウザーの制御 → スマート アプリ コントロールの設定で「オフ」を選び、iPing を再起動してください。一度オフにすると、Windows を再インストールしない限り再度オンにはできません。",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("コアの状態"),
    "country": MessageLookupByLibrary.simpleMessage("地域"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("クラッシュを検出しました"),
    "crashDetectedTip": m3,
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createProfileFromUrlTip": m4,
    "creationTime": MessageLookupByLibrary.simpleMessage("作成日時"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "起動ボタンがあるため削除できません",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "customColor": MessageLookupByLibrary.simpleMessage("カスタムカラー"),
    "customImportDroppedSubRules": m5,
    "customIssueCoreRejected": m6,
    "customIssueDialerLoop": m7,
    "customIssueDuplicateName": m8,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage("名前が空です"),
    "customIssueGroupLoop": m9,
    "customIssueInvalidEmptyFallback": m10,
    "customIssueInvalidFilter": m11,
    "customIssueMissingDialer": m12,
    "customIssueMissingProviders": m13,
    "customIssueMissingProxies": m14,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "プロキシもプロキシプロバイダーも選択されていないため、コアはこのグループを拒否します",
    ),
    "customIssueReservedName": m15,
    "customIssuesSummary": m16,
    "customProfile": MessageLookupByLibrary.simpleMessage("カスタム"),
    "customProfileDesc": MessageLookupByLibrary.simpleMessage(
      "アプリのプロキシと他のプロファイルからプロキシグループとルールを組み立てます",
    ),
    "customProfileResources": MessageLookupByLibrary.simpleMessage(
      "カスタムプロファイルのリソース",
    ),
    "customProfileResourcesDesc": MessageLookupByLibrary.simpleMessage(
      "カスタムプロファイルのリソースには、プロキシ、ルールプロバイダー、フィルター、アイコンセットがあります。",
    ),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage("追加できるカード"),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "変更の保存に失敗したため、元に戻しました",
    ),
    "daysAgo": m17,
    "daysAgoShort": m18,
    "defaultSelected": MessageLookupByLibrary.simpleMessage("デフォルトの選択"),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "設定は name と type を含む YAML マッピングである必要があります",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("失敗"),
    "delayTest": MessageLookupByLibrary.simpleMessage("遅延テスト"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m19,
    "deleteTip": m20,
    "desc": MessageLookupByLibrary.simpleMessage(
      "ClashMetaベースのマルチプラットフォーム対応プロキシクライアント。シンプルで使いやすく、オープンソースで広告もありません。",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("宛先"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("宛先GeoIP"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("宛先IP ASN"),
    "details": m21,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "サードパーティAPIに依存しているため、参考値です",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("開発者モード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "開発者モードが有効になりました。",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("ダイヤラープロキシ"),
    "dialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "ダイヤラープロキシは NTP サーバーへの接続に使用するアウトバウンドです。",
    ),
    "dialerProxyLoopStopped": m22,
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "ICMP 転送を無効化",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "ICMP 転送を無効にすると TUN が ping に直接応答するため、ping に実際の遅延が表示されなくなります。",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage("TCP キープアライブを無効化"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("UDPを無効化"),
    "disabled": MessageLookupByLibrary.simpleMessage("無効"),
    "discardChanges": MessageLookupByLibrary.simpleMessage("変更を破棄しますか？"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責事項"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアをインストール、複製または使用した時点で、本声明のすべての内容を読み、同意したものとみなされます。いずれかの条項に同意いただけない場合は、直ちに使用を中止し、本ソフトウェアをアンインストールしてください。",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("声明への同意"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "この声明を読み、理解しました",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "内容を理解したことを確認するため、以下の声明を読み、下のチェックボックスをオンにしてください：",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage("声明の確認"),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "開発者はバージョンの更新に伴い本声明を変更することがあり、変更内容は新しいバージョンの公開とともに効力を生じます。更新後も本ソフトウェアを引き続き使用した場合、変更後の声明に同意したものとみなされます。",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage("本声明の変更"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "iPing（以下「本ソフトウェア」）をご利用になる前に、本声明の内容をよくお読みになり、十分にご理解ください。「同意する」をタップすると、以下のすべての条項を読み、理解し、承諾したものとみなされます。同意いただけない場合は「終了」をタップし、本ソフトウェアの使用を中止してください。",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "適用法で認められる最大限の範囲において、開発者およびすべての貢献者は、本ソフトウェアの使用または使用不能に起因する直接的、間接的、偶発的、特別、懲罰的または結果的な損害（データの消失、機器の損傷、ネットワーク障害、業務の中断、逸失利益、およびそれに起因する法的紛争を含むがこれらに限らない）について、その可能性を知らされていた場合であっても、一切責任を負いません。",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage("責任の制限"),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは GPL-3.0 ライセンスのもとでオープンソースとして公開されています。同ライセンスを遵守する限り、自由に使用、改変、再配布できますが、派生物も GPL-3.0 で公開し、原著作者の著作権表示を保持する必要があります。\n\n本ソフトウェアに含まれるサードパーティのコンポーネント（Clash.Meta コアを含む）は、それぞれのライセンスに従います。改変版や再配布版に起因する問題について、原著作者は責任を負いません。",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "オープンソースライセンス",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェア自体は、プロキシサーバー、ノード、サブスクリプション、ネットワーク接続サービスを一切提供しておらず、それらのサービス提供者と提携、代理、保証の関係はありません。",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは、サブスクリプション URL、ノード情報、設定内容、閲覧したウェブサイト、接続記録、通信内容、ログを収集またはアップロードしません。これらのデータは端末内にのみ保存され、開発者がアクセスすることはできません。\n\n本ソフトウェアが外部ネットワークにアクセスするのは、プロファイル更新時に指定されたサブスクリプション URL へアクセスする場合や、アップデート確認時に GitHub へアクセスする場合など、該当する機能を使用したときのみです。\n\n本ソフトウェアには、どのプラットフォームでも統計やクラッシュレポートのサービスは一切組み込まれていません。",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "データ収集とプライバシー",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "お住まいの国または地域で本ソフトウェアの使用が合法であることはご自身で確認する必要があり、本ソフトウェアを使用したすべての行為とその結果について、ご自身が単独で法的責任を負います。\n\nインポートするサブスクリプション、ノード、設定はご自身の判断で選択したものです。その出所の適法性、内容の安全性、サービスの安定性については、利用者と各提供者の間で解決してください。",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "利用者の責任",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage("上記の声明を入力"),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "声明の内容と一致しません",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "内容を理解したことを確認するため、以下の声明を下の入力欄に正確に入力してください：",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage("声明の復唱"),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは Clash.Meta（mihomo）コアをベースとしたオープンソースのネットワークプロキシクライアントであり、設定管理、ルールによる振り分け、トラフィック転送などのローカルツール機能のみを提供します。",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "ソフトウェアの性質",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンク、設定ファイル、ルールセット、スクリプト、外部リソース、外部リンクはすべて第三者が提供するものであり、開発者はその適法性、正確性、安全性、可用性を審査または保証することはできず、また行いません。\n\nサードパーティのコンテンツの使用に起因する情報漏えい、財産上の損失、アカウント停止その他の損失は、利用者と第三者の間で解決するものとし、開発者は一切責任を負いません。",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "サードパーティのコンテンツ",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは学習、交流、技術研究などの非商用目的でのみ使用できます。有償配布、抱き合わせ販売、商用サービスの一部としての利用、本ソフトウェアの名義での事業活動など、あらゆる商用目的での使用を固く禁じます。いかなる商業行為も本ソフトウェアおよび開発者とは一切関係ありません。\n\nお住まいの国または地域の法令に違反する目的での使用を固く禁じます。これには、法に基づくネットワークアクセス制限の回避、違法情報の拡散、サイバー攻撃、他者の権利の侵害などが含まれますが、これらに限りません。",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("使用の制限"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは「現状のまま」かつ「提供可能な範囲で」提供され、商品性、特定目的への適合性、非侵害、継続的な可用性、エラーやセキュリティ上の脆弱性がないことの保証を含め、明示または黙示を問わずいかなる保証も伴いません。\n\n開発者は、本ソフトウェアが利用者の要件を満たすこと、また中断やエラーなく動作することを保証しません。",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage("無保証"),
    "disconnected": MessageLookupByLibrary.simpleMessage("切断済み"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "新しいバージョンが見つかりました",
    ),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "追加しない場合、ポート 53 宛てのすべての DNS 問い合わせをハイジャックします（any:53）。",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNSハイジャック"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "ここで追加した項目は、すべての URL・ファイルプロファイルの DNS を上書きします。追加していない項目はプロファイル自身の設定のままです。カスタムプロファイルの DNS はその内容で設定します。",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNSクエリ"),
    "docked": MessageLookupByLibrary.simpleMessage("固定"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "done": MessageLookupByLibrary.simpleMessage("完了"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage("ダウンロード帯域幅"),
    "duration": MessageLookupByLibrary.simpleMessage("経過時間"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("ダッシュボードを編集"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("グローバルルールを編集"),
    "editProxy": MessageLookupByLibrary.simpleMessage("プロキシを編集"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを編集"),
    "editRule": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "editSsid": MessageLookupByLibrary.simpleMessage("SSIDを編集"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage("エディターを利用できません"),
    "elapsed": MessageLookupByLibrary.simpleMessage("所要時間"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("空グループのフォールバック"),
    "emptyTip": m23,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "enabled": MessageLookupByLibrary.simpleMessage("有効"),
    "entries": MessageLookupByLibrary.simpleMessage(" 件"),
    "error": MessageLookupByLibrary.simpleMessage("エラー"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("エラーの詳細"),
    "es": MessageLookupByLibrary.simpleMessage("スペイン語"),
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから隠す"),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage("除外宛先ポート"),
    "excludeDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "除外宛先ポートへの通信は TUN を通りません。",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("除外フィルター"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("除外インターフェース"),
    "excludeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "docker0 などの除外インターフェースから入る通信は TUN を通りません。",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage("除外送信元ポート"),
    "excludeSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "除外送信元ポートからの通信は TUN を通りません。",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("除外SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "除外した SSID の Wi-Fi に接続すると、アプリの実行状態が自動的に切り替わります。",
    ),
    "excludeUid": MessageLookupByLibrary.simpleMessage("除外ユーザー ID"),
    "excludeUidDesc": MessageLookupByLibrary.simpleMessage(
      "除外ユーザー ID のプロセスの通信は TUN を通りません。",
    ),
    "existsTip": m24,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("全画面表示を終了"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("出口ノード"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("期待するステータス"),
    "expireTime": MessageLookupByLibrary.simpleMessage("有効期限"),
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポートが完了しました"),
    "extend": MessageLookupByLibrary.simpleMessage("拡張"),
    "extendMode": MessageLookupByLibrary.simpleMessage("拡張モード"),
    "extendScript": MessageLookupByLibrary.simpleMessage("拡張スクリプト"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "外部コントローラーを有効にすると、ポート 9090 でコアを制御できます。",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "外部コントローラーのシークレット",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("特大"),
    "fade": MessageLookupByLibrary.simpleMessage("フェード"),
    "failedCount": m25,
    "failedItem": m26,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IPフィルター"),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage("Fake-IPフィルターモード"),
    "fakeipFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Fake-IP フィルターモードでは、blacklist は一致を除外、whitelist は一致のみ、rule はルールで判定します。",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP範囲"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage("Fake-IP範囲（IPv6）"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("プロファイルファイルを直接アップロードします"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されています。変更を保存しますか？",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("フィルター"),
    "filters": MessageLookupByLibrary.simpleMessage("フィルター"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "floating": MessageLookupByLibrary.simpleMessage("フローティング"),
    "followProfile": MessageLookupByLibrary.simpleMessage("プロファイルに従う"),
    "followSystem": MessageLookupByLibrary.simpleMessage("システムに従う"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォント"),
    "fontSize": MessageLookupByLibrary.simpleMessage("サイズ"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("DNSマッピングを強制"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "DNS マッピングを強制すると、DNS マッピングでドメインを得た接続もスニッフィングします。",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("強制するドメイン"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "強制するドメインもスニッフィングします。ドメインを持つその他の接続は対象外です。",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "コアを強制再起動してもよろしいですか？",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("フランス語"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m27,
    "geoUpdated": m28,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低メモリモード"),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("開く"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "追加ルール設定へ移動",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("スクリプト設定へ移動"),
    "grid": MessageLookupByLibrary.simpleMessage("グリッド"),
    "groupCount": m29,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("個"),
    "groupIcons": MessageLookupByLibrary.simpleMessage("グループのアイコン"),
    "groupTimeoutCount": m30,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "hashByInUser": MessageLookupByLibrary.simpleMessage("インバウンドユーザーでハッシュ"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("ヘルスチェック"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper サービスが利用できないため、TUN モードを有効にできません。iPing を再インストールしてください。",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("16進数"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("リストから隠す"),
    "hideIp": MessageLookupByLibrary.simpleMessage("IP を隠す"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("パスワードを隠す"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "タイムアウトしたプロキシを隠す",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "前回の遅延テストがタイムアウトしたプロキシを表示しない",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("ホップ間隔"),
    "host": MessageLookupByLibrary.simpleMessage("ホスト"),
    "hostname": MessageLookupByLibrary.simpleMessage("ホスト名"),
    "hotkeyConflictWith": m31,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "グローバルホットキーはウィンドウが非表示でも有効です。アクションをタップしてキーの組み合わせを記録します。",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ホットキー管理"),
    "hotkeyNeedsModifier": m32,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("未設定"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "登録できませんでした。他のアプリが使用している可能性があります",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "hoursAgo": m33,
    "hoursAgoShort": m34,
    "hue": MessageLookupByLibrary.simpleMessage("色相"),
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("アイコン履歴"),
    "iconSets": MessageLookupByLibrary.simpleMessage("アイコンセット"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "アイコンセットはまだありません。「カスタムプロファイルのリソース → アイコンセット」で追加できます",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("背景あり"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("非表示"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("背景なし"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("アイコンURL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "電池の最適化を無視",
    ),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "このファイルはインポートできる設定ではありません",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "インポートすると、このプロファイルの現在のプロキシグループ、ルール、設定が置き換えられます",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("リンクからインポート"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "inbound": MessageLookupByLibrary.simpleMessage("インバウンド"),
    "includeInterface": MessageLookupByLibrary.simpleMessage("対象インターフェース"),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "対象インターフェースから入る通信だけが TUN を通り、除外インターフェースは無効になります。",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("対象ユーザー ID"),
    "includeUidDesc": MessageLookupByLibrary.simpleMessage(
      "対象ユーザー ID のプロセスの通信だけが TUN を通ります。",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("無期限"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "initFailed": MessageLookupByLibrary.simpleMessage("起動に失敗しました"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "iPing の起動中にエラーが発生したため、続行できません。詳細をコピーして問題を報告できます。繰り返し発生する場合は、データを消去すると起動できるようになることがあります。",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("発信元"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("発信元"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名を入力してください",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("ルールの内容を入力してください"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "アプリ一覧の権限が拒否されたため、インストール済みアプリを取得できません。システム設定から手動で許可してください。",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "このシステムでは、許可するまでインストール済みアプリの一覧が提供されません。許可すると、アプリごとのプロキシを設定できます。",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "アプリ一覧の権限が必要です",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("インストール済みのフォント"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("スマート選択"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("インターフェース名"),
    "interfaceNameDesc": MessageLookupByLibrary.simpleMessage(
      "インターフェース名は、アウトバウンド接続に使用するネットワークインターフェースです。",
    ),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "アウトバウンドインターフェース",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("クリア"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("設定に従う"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("間隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネットIP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("無効なバックアップファイル"),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "192.168.0.0/16 のような CIDR 形式の IP 範囲を入力してください",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "DSCP マークは 63 を超えられません",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "ドメインまたは IP アドレスを入力してください",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage("有効なアイコンセットではありません"),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクまたはプロキシの共有リンクではありません",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "0.0.0.0:1053 のようなアドレスとポートを入力してください",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "tcp または udp のみ対応しています",
    ),
    "invalidPolicy": m35,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "443 や 8000-9000 のようなポートまたは範囲を入力してください",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "このQRコードにはプロファイルのリンクが含まれていません",
    ),
    "invalidProxy": m36,
    "invalidProxyProvider": m37,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "80 や 8000-9000 のような数値または範囲を / 区切りで入力してください",
    ),
    "invalidRuleSet": m38,
    "invalidSettingTip": m39,
    "invalidSubRule": m40,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP アドレス"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("不正利用の履歴"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("検出"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("組織"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "IP タイプを判定できませんでした",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("良好"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("レベル"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("普通"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("再確認"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("リスクあり"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("品質"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("採用したソース"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("各ソース"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "アウトバウンド IP が不一致",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("判定不可"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("レート制限"),
    "ipType": MessageLookupByLibrary.simpleMessage("タイプ"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("ビジネス"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("データセンター"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("モバイル回線"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("住宅"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("タイプ不明"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP バージョン"),
    "ipingAccount": MessageLookupByLibrary.simpleMessage("アカウント"),
    "ipingAccountActive": MessageLookupByLibrary.simpleMessage("有効"),
    "ipingAccountAuthorize": MessageLookupByLibrary.simpleMessage(
      "アカウントへのアクセスを許可",
    ),
    "ipingAccountAuthorizeHint": MessageLookupByLibrary.simpleMessage(
      "アカウント情報の表示を許可するには、再度ログインしてください。",
    ),
    "ipingAccountInactive": MessageLookupByLibrary.simpleMessage("無効"),
    "ipingAccountInformation": MessageLookupByLibrary.simpleMessage("アカウント情報"),
    "ipingAccountLoadFailed": MessageLookupByLibrary.simpleMessage(
      "アカウント情報を読み込めません。もう一度お試しください。",
    ),
    "ipingAccountServices": MessageLookupByLibrary.simpleMessage("アカウントサービス管理"),
    "ipingAccountServicesHint": MessageLookupByLibrary.simpleMessage(
      "Web でチャージ、Telegram 連携、API キーと通知の管理ができます。",
    ),
    "ipingAccountSettings": MessageLookupByLibrary.simpleMessage("アカウント設定"),
    "ipingActualTraffic": MessageLookupByLibrary.simpleMessage("実際の通信量"),
    "ipingApiAuthorized": MessageLookupByLibrary.simpleMessage("このデバイスで認証済み"),
    "ipingApiKey": MessageLookupByLibrary.simpleMessage("API Key"),
    "ipingAvailableBalance": MessageLookupByLibrary.simpleMessage("利用可能残高"),
    "ipingBalance": MessageLookupByLibrary.simpleMessage("残高（人民元）"),
    "ipingBilledTraffic": MessageLookupByLibrary.simpleMessage("課金対象の通信量"),
    "ipingBilling": MessageLookupByLibrary.simpleMessage("請求と残高履歴"),
    "ipingBrandDescription": MessageLookupByLibrary.simpleMessage(
      "使い慣れたアカウントでサブスクリプション、ノード、ネットワーク接続を一元管理。",
    ),
    "ipingBrandEyebrow": MessageLookupByLibrary.simpleMessage("グローバルな接続"),
    "ipingBrandHeadline": MessageLookupByLibrary.simpleMessage("もっと広い世界へ。"),
    "ipingBrandHeadlineAccent": MessageLookupByLibrary.simpleMessage(
      "もっとシンプルな接続を。",
    ),
    "ipingBrowserHint": m41,
    "ipingBrowserLogin": MessageLookupByLibrary.simpleMessage("ブラウザでログイン"),
    "ipingBrowserWaiting": MessageLookupByLibrary.simpleMessage(
      "ブラウザでログインを完了し、iPing に戻ってください。",
    ),
    "ipingConsole": MessageLookupByLibrary.simpleMessage("iPing コンソールを開く"),
    "ipingCredentialsError": MessageLookupByLibrary.simpleMessage(
      "メールアドレスまたはパスワードが正しくありません。",
    ),
    "ipingDevice": MessageLookupByLibrary.simpleMessage("デバイス"),
    "ipingDiagnostics": MessageLookupByLibrary.simpleMessage("接続診断"),
    "ipingDiagnosticsHint": MessageLookupByLibrary.simpleMessage(
      "システム DNS と出口は別々に確認します。出口の失敗だけでは DNS 障害と判断できません。ネットワーク設定は変更しません。",
    ),
    "ipingDnsFailed": MessageLookupByLibrary.simpleMessage(
      "アドレスを解決できません。ネットワークとシステム DNS を確認してください。",
    ),
    "ipingDnsOk": MessageLookupByLibrary.simpleMessage("サーバーアドレスを解決できました。"),
    "ipingEmail": MessageLookupByLibrary.simpleMessage("メールアドレス"),
    "ipingEmailInvalid": MessageLookupByLibrary.simpleMessage(
      "有効なメールアドレスを入力してください。",
    ),
    "ipingExitCheck": MessageLookupByLibrary.simpleMessage("現在の出口の接続"),
    "ipingExitFailed": MessageLookupByLibrary.simpleMessage(
      "出口から応答がありません。ノードを変更して再確認してください。",
    ),
    "ipingExitOk": MessageLookupByLibrary.simpleMessage("現在の出口から応答がありました。"),
    "ipingFeatureConnect": MessageLookupByLibrary.simpleMessage("柔軟なノード選択"),
    "ipingFeatureLogin": MessageLookupByLibrary.simpleMessage("ブラウザーでログイン"),
    "ipingFeatureSync": MessageLookupByLibrary.simpleMessage("サブスクリプション自動同期"),
    "ipingForgotPassword": MessageLookupByLibrary.simpleMessage(
      "パスワードをお忘れですか？",
    ),
    "ipingGateway": MessageLookupByLibrary.simpleMessage("プロキシとトンネル"),
    "ipingImportSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクをインポート",
    ),
    "ipingImportWithoutLogin": MessageLookupByLibrary.simpleMessage(
      "ログインせずにサブスクリプションをインポート",
    ),
    "ipingJoinedAt": MessageLookupByLibrary.simpleMessage("登録日時"),
    "ipingLoginHint": MessageLookupByLibrary.simpleMessage(
      "ログインするとサブスクリプションを自動で読み込みます。",
    ),
    "ipingLoginSecurityNote": MessageLookupByLibrary.simpleMessage(
      "認証はブラウザーで行います。クライアントはパスワードを保存しません。",
    ),
    "ipingManualNoNodes": MessageLookupByLibrary.simpleMessage(
      "利用可能なノードがありません。サブスクリプションリンクを確認するか、更新してください。",
    ),
    "ipingManualSubscription": MessageLookupByLibrary.simpleMessage(
      "手動でインポートしたサブスクリプション",
    ),
    "ipingNativeIp": MessageLookupByLibrary.simpleMessage("ネイティブ IP"),
    "ipingNativeIpAll": MessageLookupByLibrary.simpleMessage("すべて"),
    "ipingNativeIpBundle": MessageLookupByLibrary.simpleMessage("トンネルも購入"),
    "ipingNativeIpBundleHint": MessageLookupByLibrary.simpleMessage(
      "IP ごとにトンネルを 1 つ設定します。",
    ),
    "ipingNativeIpBuy": MessageLookupByLibrary.simpleMessage("購入"),
    "ipingNativeIpClearTags": m42,
    "ipingNativeIpConfigureLater": MessageLookupByLibrary.simpleMessage(
      "IP の提供後にトンネルを自動設定します。",
    ),
    "ipingNativeIpConfigureNow": MessageLookupByLibrary.simpleMessage(
      "購入完了と同時にトンネルを設定します。",
    ),
    "ipingNativeIpContinentAF": MessageLookupByLibrary.simpleMessage("アフリカ"),
    "ipingNativeIpContinentAN": MessageLookupByLibrary.simpleMessage("南極"),
    "ipingNativeIpContinentAS": MessageLookupByLibrary.simpleMessage("アジア"),
    "ipingNativeIpContinentEU": MessageLookupByLibrary.simpleMessage("ヨーロッパ"),
    "ipingNativeIpContinentNA": MessageLookupByLibrary.simpleMessage("北アメリカ"),
    "ipingNativeIpContinentOC": MessageLookupByLibrary.simpleMessage("オセアニア"),
    "ipingNativeIpContinentSA": MessageLookupByLibrary.simpleMessage("南アメリカ"),
    "ipingNativeIpCopyAddress": MessageLookupByLibrary.simpleMessage(
      "アドレスをコピー",
    ),
    "ipingNativeIpCopyCredentials": MessageLookupByLibrary.simpleMessage(
      "認証情報をコピー",
    ),
    "ipingNativeIpCopyUrl": MessageLookupByLibrary.simpleMessage(
      "プロキシ URL をコピー",
    ),
    "ipingNativeIpCount": MessageLookupByLibrary.simpleMessage("数量"),
    "ipingNativeIpCountInvalid": m43,
    "ipingNativeIpDuration": MessageLookupByLibrary.simpleMessage("期間"),
    "ipingNativeIpEmpty": MessageLookupByLibrary.simpleMessage(
      "購入できるネイティブ IP はありません",
    ),
    "ipingNativeIpFilteredEmpty": MessageLookupByLibrary.simpleMessage(
      "条件に一致する地域はありません",
    ),
    "ipingNativeIpInTunnel": MessageLookupByLibrary.simpleMessage("トンネルで使用中"),
    "ipingNativeIpLineA": MessageLookupByLibrary.simpleMessage("回線 A"),
    "ipingNativeIpLineB": MessageLookupByLibrary.simpleMessage("回線 B"),
    "ipingNativeIpLineC": MessageLookupByLibrary.simpleMessage("回線 C"),
    "ipingNativeIpListPrice": MessageLookupByLibrary.simpleMessage(
      "表示は定価です。再販割引は請求時に適用されます。",
    ),
    "ipingNativeIpLoadFailed": MessageLookupByLibrary.simpleMessage(
      "ネイティブ IP を読み込めませんでした。もう一度お試しください。",
    ),
    "ipingNativeIpMonthly": m44,
    "ipingNativeIpMonths": m45,
    "ipingNativeIpNoPlans": MessageLookupByLibrary.simpleMessage(
      "購入できるトンネルプランはありません。",
    ),
    "ipingNativeIpOneMonth": MessageLookupByLibrary.simpleMessage("1 か月"),
    "ipingNativeIpOpenTunnels": MessageLookupByLibrary.simpleMessage("トンネルへ移動"),
    "ipingNativeIpOrder": MessageLookupByLibrary.simpleMessage("注文"),
    "ipingNativeIpOwned": MessageLookupByLibrary.simpleMessage("購入済み"),
    "ipingNativeIpOwnedEmpty": MessageLookupByLibrary.simpleMessage(
      "ネイティブ IP はまだありません。",
    ),
    "ipingNativeIpPlan": MessageLookupByLibrary.simpleMessage("トンネルプラン"),
    "ipingNativeIpPlansFailed": MessageLookupByLibrary.simpleMessage(
      "トンネルプランを読み込めませんでした。IP のみ購入できます。",
    ),
    "ipingNativeIpPurchaseFailed": MessageLookupByLibrary.simpleMessage(
      "購入を完了できませんでした。もう一度お試しください。",
    ),
    "ipingNativeIpPurchased": MessageLookupByLibrary.simpleMessage(
      "注文しました。IP の提供後にノードへ表示されます。",
    ),
    "ipingNativeIpPurchasedTunnelLater": MessageLookupByLibrary.simpleMessage(
      "注文しました。トンネルは IP の提供後に自動設定されます。",
    ),
    "ipingNativeIpPurchasedWithTunnel": MessageLookupByLibrary.simpleMessage(
      "注文しました。トンネルの設定は完了しています。",
    ),
    "ipingNativeIpResultCount": m46,
    "ipingNativeIpSoldOut": MessageLookupByLibrary.simpleMessage("売り切れ"),
    "ipingNativeIpStock": m47,
    "ipingNativeIpTags": MessageLookupByLibrary.simpleMessage("タグ"),
    "ipingNativeIpTagsHint": MessageLookupByLibrary.simpleMessage(
      "選択したタグをすべて満たす",
    ),
    "ipingNativeIpTotal": MessageLookupByLibrary.simpleMessage("合計"),
    "ipingNetwork": MessageLookupByLibrary.simpleMessage("世界のネットワーク"),
    "ipingNetworkError": MessageLookupByLibrary.simpleMessage(
      "接続できません。ネットワークを確認して再試行してください。前回のサブスクリプションは保持されています。",
    ),
    "ipingNoNodes": MessageLookupByLibrary.simpleMessage(
      "利用可能なノードがありません。iPing コンソールでサービスを管理してから更新してください。",
    ),
    "ipingNoPaymentMethods": MessageLookupByLibrary.simpleMessage(
      "現在利用できる支払い方法はありません。",
    ),
    "ipingNoTraffic": MessageLookupByLibrary.simpleMessage("この期間の通信記録はありません。"),
    "ipingNodeCount": m48,
    "ipingNotifications": MessageLookupByLibrary.simpleMessage("Telegram 通知"),
    "ipingNotificationsHint": MessageLookupByLibrary.simpleMessage(
      "Web と同じ通知設定です。Telegram と連携すると通知を受信できます。設定は Web で変更できます。",
    ),
    "ipingNotifyIp": MessageLookupByLibrary.simpleMessage("IP 有効期限の通知"),
    "ipingNotifyTopup": MessageLookupByLibrary.simpleMessage("チャージ通知"),
    "ipingNotifyTunnel": MessageLookupByLibrary.simpleMessage("トンネル有効期限の通知"),
    "ipingPassword": MessageLookupByLibrary.simpleMessage("パスワード"),
    "ipingPasswordRequired": MessageLookupByLibrary.simpleMessage(
      "パスワードを入力してください。",
    ),
    "ipingPaymentFee": m49,
    "ipingPaymentMethod": MessageLookupByLibrary.simpleMessage("支払い方法"),
    "ipingPaymentRequired": MessageLookupByLibrary.simpleMessage(
      "支払い方法を選択してください。",
    ),
    "ipingPopupNoticeConfirm": MessageLookupByLibrary.simpleMessage("了解"),
    "ipingPopupNoticeTitle": MessageLookupByLibrary.simpleMessage("お知らせ"),
    "ipingPrivacy": MessageLookupByLibrary.simpleMessage("プライバシーポリシー"),
    "ipingProfileCenter": MessageLookupByLibrary.simpleMessage("アカウントセンター"),
    "ipingProxyCheck": MessageLookupByLibrary.simpleMessage("プロキシ状態"),
    "ipingRecentTopups": MessageLookupByLibrary.simpleMessage("最近のチャージ"),
    "ipingReferralCount": MessageLookupByLibrary.simpleMessage("紹介人数"),
    "ipingReferralEarnings": MessageLookupByLibrary.simpleMessage("累計報酬（人民元）"),
    "ipingReferralHint": MessageLookupByLibrary.simpleMessage(
      "紹介したユーザーがチャージすると、報酬率に応じた報酬を受け取れます。",
    ),
    "ipingReferralInformation": MessageLookupByLibrary.simpleMessage("紹介情報"),
    "ipingReferralLink": MessageLookupByLibrary.simpleMessage("紹介リンク"),
    "ipingReferralRate": MessageLookupByLibrary.simpleMessage("報酬率"),
    "ipingRefreshAccount": MessageLookupByLibrary.simpleMessage("アカウント情報を更新"),
    "ipingRegister": MessageLookupByLibrary.simpleMessage("アカウントを作成"),
    "ipingRegistrationClosed": MessageLookupByLibrary.simpleMessage(
      "現在、新規登録は受け付けていません。既存のアカウントでログインできます。",
    ),
    "ipingRenewalShortfall": MessageLookupByLibrary.simpleMessage(
      "残高が自動更新に足りない可能性があります",
    ),
    "ipingRenewalShortfallDetail": m50,
    "ipingRunDiagnostics": MessageLookupByLibrary.simpleMessage("再チェック"),
    "ipingSafeDiagnostics": MessageLookupByLibrary.simpleMessage(
      "セーフモードではプロキシと出口を確認できません。",
    ),
    "ipingSessionExpired": MessageLookupByLibrary.simpleMessage(
      "セッションが無効です。もう一度ログインしてください。",
    ),
    "ipingSignIn": MessageLookupByLibrary.simpleMessage("ログイン"),
    "ipingSignOut": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "ipingStartToCheck": MessageLookupByLibrary.simpleMessage(
      "接続を開始して出口を確認してください。",
    ),
    "ipingStorageError": MessageLookupByLibrary.simpleMessage(
      "アカウント情報を保存できません。保存権限を確認して再試行してください。",
    ),
    "ipingSubscriptionCheck": MessageLookupByLibrary.simpleMessage("サブスクリプション"),
    "ipingSubscriptionError": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを読み込めません。リンクを確認するか、再試行してください。",
    ),
    "ipingSync": MessageLookupByLibrary.simpleMessage("サブスクリプションを更新"),
    "ipingSyncing": MessageLookupByLibrary.simpleMessage("更新中…"),
    "ipingSystemDns": m51,
    "ipingTelegram": MessageLookupByLibrary.simpleMessage("Telegram"),
    "ipingTelegramBound": MessageLookupByLibrary.simpleMessage("連携済み"),
    "ipingTelegramUnbound": MessageLookupByLibrary.simpleMessage("未連携"),
    "ipingTerms": MessageLookupByLibrary.simpleMessage("利用規約"),
    "ipingTopUp": MessageLookupByLibrary.simpleMessage("チャージ"),
    "ipingTopupActivityFixed": m52,
    "ipingTopupActivityFrom": m53,
    "ipingTopupActivityPercent": m54,
    "ipingTopupActivityUpTo": m55,
    "ipingTopupAmount": MessageLookupByLibrary.simpleMessage("チャージ金額"),
    "ipingTopupBelowMinimum": m56,
    "ipingTopupBonus": m57,
    "ipingTopupCancel": MessageLookupByLibrary.simpleMessage("注文をキャンセル"),
    "ipingTopupCancelConfirm": MessageLookupByLibrary.simpleMessage(
      "この未払いの注文をキャンセルしますか？キャンセル後に新しく注文できます。",
    ),
    "ipingTopupCancelFailed": MessageLookupByLibrary.simpleMessage(
      "注文をキャンセルできませんでした。もう一度お試しください。",
    ),
    "ipingTopupCredited": MessageLookupByLibrary.simpleMessage("受取額"),
    "ipingTopupEmpty": MessageLookupByLibrary.simpleMessage("チャージ履歴はありません"),
    "ipingTopupFailed": MessageLookupByLibrary.simpleMessage(
      "注文を作成できませんでした。もう一度お試しください。",
    ),
    "ipingTopupHistory": MessageLookupByLibrary.simpleMessage("チャージ履歴"),
    "ipingTopupHistoryFailed": MessageLookupByLibrary.simpleMessage(
      "チャージ履歴を読み込めませんでした。もう一度お試しください。",
    ),
    "ipingTopupMinimum": m58,
    "ipingTopupOpened": MessageLookupByLibrary.simpleMessage(
      "ブラウザで支払いを完了してください。支払い後、残高に自動で反映されます。",
    ),
    "ipingTopupOptionsFailed": MessageLookupByLibrary.simpleMessage(
      "チャージオプションを読み込めませんでした。もう一度お試しください。",
    ),
    "ipingTopupOtherAmount": MessageLookupByLibrary.simpleMessage("その他の金額"),
    "ipingTopupPay": MessageLookupByLibrary.simpleMessage("支払う"),
    "ipingTopupPendingExists": MessageLookupByLibrary.simpleMessage(
      "未払いの注文があります。先にチャージ履歴で支払うかキャンセルしてください。",
    ),
    "ipingTopupStatusCancelled": MessageLookupByLibrary.simpleMessage(
      "キャンセル済み",
    ),
    "ipingTopupStatusPending": MessageLookupByLibrary.simpleMessage("未払い"),
    "ipingTopupStatusSuccess": MessageLookupByLibrary.simpleMessage("完了"),
    "ipingTraffic30Days": MessageLookupByLibrary.simpleMessage(
      "通信量 · 過去 30 日間",
    ),
    "ipingTunnelAutoRenew": MessageLookupByLibrary.simpleMessage("自動更新"),
    "ipingTunnelAutoRenewDesc": MessageLookupByLibrary.simpleMessage(
      "有効期限の前日に自動更新されます。残高をご確認ください",
    ),
    "ipingTunnelBatchCopyAddresses": MessageLookupByLibrary.simpleMessage(
      "アドレスをコピー",
    ),
    "ipingTunnelBatchCopyEmpty": MessageLookupByLibrary.simpleMessage(
      "選択したトンネルに有効なアドレスがありません",
    ),
    "ipingTunnelBatchCopySuccess": m59,
    "ipingTunnelBatchFillAddresses": MessageLookupByLibrary.simpleMessage(
      "IPを一括入力",
    ),
    "ipingTunnelBatchFillAddressesHint": MessageLookupByLibrary.simpleMessage(
      "1行に1件、順次反映。空欄の場合は変更しません",
    ),
    "ipingTunnelBatchFillNames": MessageLookupByLibrary.simpleMessage(
      "名前を一括入力",
    ),
    "ipingTunnelBatchFillNamesGenerate": MessageLookupByLibrary.simpleMessage(
      "連番生成",
    ),
    "ipingTunnelBatchFillNamesPrefix": MessageLookupByLibrary.simpleMessage(
      "接頭辞（例: 東京）",
    ),
    "ipingTunnelBatchOperations": MessageLookupByLibrary.simpleMessage("一括操作"),
    "ipingTunnelBatchRenew": MessageLookupByLibrary.simpleMessage("一括更新"),
    "ipingTunnelBatchRenewBalance": MessageLookupByLibrary.simpleMessage(
      "現在の残高",
    ),
    "ipingTunnelBatchRenewConfirm": MessageLookupByLibrary.simpleMessage(
      "一括更新を確認",
    ),
    "ipingTunnelBatchRenewInsufficient": MessageLookupByLibrary.simpleMessage(
      "残高不足です。チャージしてください",
    ),
    "ipingTunnelBatchRenewSuccess": m60,
    "ipingTunnelBatchRenewTotal": MessageLookupByLibrary.simpleMessage("合計予定"),
    "ipingTunnelBatchSelected": m61,
    "ipingTunnelBatchStatusNoChange": MessageLookupByLibrary.simpleMessage(
      "変更なし",
    ),
    "ipingTunnelBatchUpdate": MessageLookupByLibrary.simpleMessage("一括設定"),
    "ipingTunnelBatchUpdateSuccess": MessageLookupByLibrary.simpleMessage(
      "一括更新に成功しました",
    ),
    "ipingTunnelCopyListen": MessageLookupByLibrary.simpleMessage("待受アドレスをコピー"),
    "ipingTunnelEdit": MessageLookupByLibrary.simpleMessage("トンネルを編集"),
    "ipingTunnelEntrance": MessageLookupByLibrary.simpleMessage("入口"),
    "ipingTunnelExit": MessageLookupByLibrary.simpleMessage("出口"),
    "ipingTunnelExpired": MessageLookupByLibrary.simpleMessage("期限切れ"),
    "ipingTunnelExpires": MessageLookupByLibrary.simpleMessage("有効期限"),
    "ipingTunnelExport": MessageLookupByLibrary.simpleMessage("エクスポート"),
    "ipingTunnelExportClash": MessageLookupByLibrary.simpleMessage(
      "Clash プロキシ（YAML）",
    ),
    "ipingTunnelExportCsv": MessageLookupByLibrary.simpleMessage("CSV"),
    "ipingTunnelExportLines": MessageLookupByLibrary.simpleMessage(
      "host:port:user:pass",
    ),
    "ipingTunnelExportSuccess": m62,
    "ipingTunnelFilterAll": MessageLookupByLibrary.simpleMessage("すべて"),
    "ipingTunnelFilterAutoRenew": MessageLookupByLibrary.simpleMessage("自動更新"),
    "ipingTunnelFilterAutoRenewOff": MessageLookupByLibrary.simpleMessage("無効"),
    "ipingTunnelFilterAutoRenewOn": MessageLookupByLibrary.simpleMessage("有効"),
    "ipingTunnelFilterIpType": MessageLookupByLibrary.simpleMessage("IP タイプ"),
    "ipingTunnelFilterPort": MessageLookupByLibrary.simpleMessage("待受ポート"),
    "ipingTunnelFilterPortHint": MessageLookupByLibrary.simpleMessage(
      "ポート番号を入力",
    ),
    "ipingTunnelFilterReset": MessageLookupByLibrary.simpleMessage(
      "フィルターをリセット",
    ),
    "ipingTunnelFilterTitle": MessageLookupByLibrary.simpleMessage("フィルター"),
    "ipingTunnelFilterType": MessageLookupByLibrary.simpleMessage("トンネルタイプ"),
    "ipingTunnelForward": MessageLookupByLibrary.simpleMessage("転送先"),
    "ipingTunnelForwardAddressRequired": MessageLookupByLibrary.simpleMessage(
      "転送先アドレスを入力してください",
    ),
    "ipingTunnelForwardHost": MessageLookupByLibrary.simpleMessage(
      "転送先 IP またはドメイン",
    ),
    "ipingTunnelForwardLocked": MessageLookupByLibrary.simpleMessage(
      "付与された IP の有効期間中は転送先アドレスを変更できません",
    ),
    "ipingTunnelForwardPort": MessageLookupByLibrary.simpleMessage("ポート"),
    "ipingTunnelImportClipboard": MessageLookupByLibrary.simpleMessage(
      "クリップボードからインポート",
    ),
    "ipingTunnelImportClipboardFailed": MessageLookupByLibrary.simpleMessage(
      "有効なプロキシアドレスを解析できませんでした",
    ),
    "ipingTunnelImportClipboardSuccess": MessageLookupByLibrary.simpleMessage(
      "クリップボードから転送先アドレスをインポートしました",
    ),
    "ipingTunnelListen": MessageLookupByLibrary.simpleMessage("待受アドレス"),
    "ipingTunnelListenWaiting": MessageLookupByLibrary.simpleMessage(
      "ポートの割り当て待ち",
    ),
    "ipingTunnelLoadMore": MessageLookupByLibrary.simpleMessage("さらに読み込む"),
    "ipingTunnelMoreAddresses": m63,
    "ipingTunnelName": MessageLookupByLibrary.simpleMessage("トンネル名"),
    "ipingTunnelNameHint": MessageLookupByLibrary.simpleMessage("トンネル名を入力"),
    "ipingTunnelPassword": MessageLookupByLibrary.simpleMessage("パスワード（任意）"),
    "ipingTunnelPoolCountry": MessageLookupByLibrary.simpleMessage("出口国/地域"),
    "ipingTunnelPoolExit": MessageLookupByLibrary.simpleMessage(
      "出口はアドレスプールから割り当てられます",
    ),
    "ipingTunnelPoolInterval": MessageLookupByLibrary.simpleMessage(
      "自動切替間隔（分）",
    ),
    "ipingTunnelPoolIntervalHint": MessageLookupByLibrary.simpleMessage(
      "0 で自動切替を無効化",
    ),
    "ipingTunnelPortConflict": MessageLookupByLibrary.simpleMessage(
      "ポートが使用中です",
    ),
    "ipingTunnelPortInvalid": MessageLookupByLibrary.simpleMessage(
      "ポートは 1 から 65535 の間である必要があります",
    ),
    "ipingTunnelRate": m64,
    "ipingTunnelReminderExpiring": m65,
    "ipingTunnelReminderTraffic": m66,
    "ipingTunnelRenew": MessageLookupByLibrary.simpleMessage("更新"),
    "ipingTunnelRenewConfirm": MessageLookupByLibrary.simpleMessage(
      "更新すると残高から引き落とされます。",
    ),
    "ipingTunnelRenewConfirmPrice": m67,
    "ipingTunnelRenewFailed": MessageLookupByLibrary.simpleMessage(
      "トンネルを更新できませんでした。もう一度お試しください。",
    ),
    "ipingTunnelRenewed": MessageLookupByLibrary.simpleMessage("更新しました"),
    "ipingTunnelSelectFromNativeIps": MessageLookupByLibrary.simpleMessage(
      "ネイティブ IP から選択",
    ),
    "ipingTunnelSelectFromNativeIpsEmpty": MessageLookupByLibrary.simpleMessage(
      "利用可能なネイティブ IP はありません",
    ),
    "ipingTunnelStatusActive": MessageLookupByLibrary.simpleMessage("有効"),
    "ipingTunnelStatusInactive": MessageLookupByLibrary.simpleMessage("無効"),
    "ipingTunnelSwitchIp": MessageLookupByLibrary.simpleMessage("出口 IP を変更"),
    "ipingTunnelSwitchIpFailed": MessageLookupByLibrary.simpleMessage(
      "出口 IP の変更に失敗しました。再試行してください",
    ),
    "ipingTunnelSwitchIpSuccess": MessageLookupByLibrary.simpleMessage(
      "出口 IP を変更しました。設定を適用中",
    ),
    "ipingTunnelSwitchPort": MessageLookupByLibrary.simpleMessage("ポートを変更"),
    "ipingTunnelSwitchPortFailed": MessageLookupByLibrary.simpleMessage(
      "ポートの変更に失敗しました。再試行してください",
    ),
    "ipingTunnelSwitchPortSuccess": MessageLookupByLibrary.simpleMessage(
      "ポートを変更しました",
    ),
    "ipingTunnelTestConnection": MessageLookupByLibrary.simpleMessage("接続をテスト"),
    "ipingTunnelTraffic": MessageLookupByLibrary.simpleMessage("通信量"),
    "ipingTunnelTrafficOf": m68,
    "ipingTunnelTypeMtcp": MessageLookupByLibrary.simpleMessage("多重化 TCP"),
    "ipingTunnelTypeMtls": MessageLookupByLibrary.simpleMessage("多重化暗号化 TLS"),
    "ipingTunnelTypeMwss": MessageLookupByLibrary.simpleMessage(
      "多重化暗号化 WebSocket",
    ),
    "ipingTunnelTypeRelayx": MessageLookupByLibrary.simpleMessage("RelayX"),
    "ipingTunnelTypeTcp": MessageLookupByLibrary.simpleMessage("TCP"),
    "ipingTunnelTypeTls": MessageLookupByLibrary.simpleMessage("暗号化 TLS"),
    "ipingTunnelTypeUdp": MessageLookupByLibrary.simpleMessage("UDP"),
    "ipingTunnelTypeWss": MessageLookupByLibrary.simpleMessage("暗号化 WebSocket"),
    "ipingTunnelUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "トンネルを変更できませんでした。もう一度お試しください。",
    ),
    "ipingTunnelUpdated": MessageLookupByLibrary.simpleMessage("変更しました"),
    "ipingTunnelUsername": MessageLookupByLibrary.simpleMessage("ユーザー名（任意）"),
    "ipingTunnels": MessageLookupByLibrary.simpleMessage("トンネル"),
    "ipingTunnelsEmpty": MessageLookupByLibrary.simpleMessage("トンネルはまだありません"),
    "ipingTunnelsFilteredEmpty": MessageLookupByLibrary.simpleMessage(
      "条件に一致するトンネルはありません",
    ),
    "ipingTunnelsLoadFailed": MessageLookupByLibrary.simpleMessage(
      "トンネルを読み込めませんでした。もう一度お試しください。",
    ),
    "ipingTunnelsResultCount": m69,
    "ipingUpdateAppStoreFailed": MessageLookupByLibrary.simpleMessage(
      "App Store を開けません。もう一度お試しください。",
    ),
    "ipingUpdateAppStoreHint": MessageLookupByLibrary.simpleMessage(
      "App Store でアップデートをインストールし、iPing を再度開いてください。",
    ),
    "ipingUpdateAvailableDesc": m70,
    "ipingUpdateCheckFailed": MessageLookupByLibrary.simpleMessage(
      "更新を確認できません。ネットワーク接続を確認して再試行してください。",
    ),
    "ipingUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "更新に失敗しました。ネットワーク接続とインストール権限を確認して再試行してください。",
    ),
    "ipingUpdateInstallHint": MessageLookupByLibrary.simpleMessage(
      "システムのインストール確認を完了してください。更新後にアプリが再起動します。",
    ),
    "ipingUpdateLater": MessageLookupByLibrary.simpleMessage("後で"),
    "ipingUpdateManualDownload": MessageLookupByLibrary.simpleMessage(
      "手動でダウンロード",
    ),
    "ipingUpdateOpenAppStore": MessageLookupByLibrary.simpleMessage(
      "App Store で更新",
    ),
    "ipingUserId": m71,
    "ipingVersion": m72,
    "ipingWelcome": m73,
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "IPv6 トラフィックは IPv6 が有効なときだけ受信します。",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "IPv6 を有効にすると、VPN で IPv6 インバウンドを許可します。",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6タイムアウト（ms）"),
    "itemsCount": m74,
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "justNow": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage("TCP キープアライブ待機時間"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCPキープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "ko": MessageLookupByLibrary.simpleMessage("韓国語"),
    "label": MessageLookupByLibrary.simpleMessage("ラベル"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "large": MessageLookupByLibrary.simpleMessage("大"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("最終更新"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("起動が完了しませんでした"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "前回、アプリは起動中に予期せず終了しました。今回の自動セットアップはスキップしました。手動で起動して再試行できます。",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "lineIssueTip": m75,
    "lineWrap": MessageLookupByLibrary.simpleMessage("折り返し"),
    "link": MessageLookupByLibrary.simpleMessage("リンク"),
    "linkDesc": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションリンクまたはプロキシの共有リンクからプロファイルを取得します",
    ),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("リキッドグラス"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リッスン"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage("リッスンのルーティングマーク"),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "リッスンのルーティングマークは Linux でのみ有効です。",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage("リアルタイム接続"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中…"),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localImage": MessageLookupByLibrary.simpleMessage("ローカル画像"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "ローカルネットワークの権限が拒否されたため gvisor スタックを使用します。LAN にはアクセスできません。",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("ローカルプロキシ"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("位置情報の権限"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が拒否されたため、現在の Wi-Fi 名を取得できません。システム設定で位置情報の権限を手動で有効にしてください。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "システムの要件により、Wi-Fi 名の取得には位置情報の権限が必要です。Android では「常に許可」を選択してください。そうしないと、アプリがバックグラウンドにあるときに Wi-Fi 名を取得できません。",
    ),
    "locationPermissionGuide": m76,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が必要です",
    ),
    "log": MessageLookupByLibrary.simpleMessage("ログ"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャプチャ"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "ログキャプチャを無効にすると、ログの入り口が非表示になります。",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage("ログと診断"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP ループバック解除"),
    "loose": MessageLookupByLibrary.simpleMessage("ゆったり"),
    "matchCase": MessageLookupByLibrary.simpleMessage("大文字と小文字を区別"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("送信元IPにマッチ"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失敗回数"),
    "maxLengthTip": m77,
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("常駐メモリ"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("アプリと共有"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("未使用のヒープ"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("使用中のヒープ"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "コアは実行されていません",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("ランタイムのオーバーヘッド"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("ゴルーチンスタック"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスの常駐メモリからの推定値で、システムの表示とは異なる場合があります。",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "コアはアプリと同じプロセスで動作します。コア分はランタイム統計から推定し、残りはアプリと共有メモリとして計上します。",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage("アプリとコアが使用するメモリ"),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("メモリを解放しました"),
    "memoryReleasedSize": m78,
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("これはメッセージです。"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minutes": MessageLookupByLibrary.simpleMessage("分"),
    "minutesAgo": m79,
    "minutesAgoShort": m80,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixedポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "monthsAgo": m81,
    "monthsAgoShort": m82,
    "more": MessageLookupByLibrary.simpleMessage("その他"),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("ボトムバー"),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkAccessDeniedError": m83,
    "networkBadResponseError": m84,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "リクエストはキャンセルされました",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "サーバーに接続できませんでした。ネットワーク接続またはプロキシ設定を確認してください",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "サーバーのアドレスを解決できませんでした。URL が正しいこと、DNS が使えることを確認してください",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("ネットワーク名"),
    "networkNotFoundError": m85,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "リクエストが多すぎます（HTTP 429）。しばらく待ってから再試行してください",
    ),
    "networkRequestFailed": m86,
    "networkSecret": MessageLookupByLibrary.simpleMessage("ネットワークシークレット"),
    "networkServerError": m87,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("トラフィックの引き継ぎ"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "リクエストがタイムアウトしました。ネットワークまたはプロキシを確認してから再試行してください",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "安全な接続に失敗しました。サーバー証明書が無効か、接続が傍受されている可能性があります",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("ネットワーク種別"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("次の一致"),
    "no": MessageLookupByLibrary.simpleMessage("いいえ"),
    "noData": MessageLookupByLibrary.simpleMessage("データがありません"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報がありません"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("今後表示しない"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークがありません"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワーク不使用アプリ"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IPを解決しない"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("ホスト名を解決しない"),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("一致する結果はありません"),
    "nodes": MessageLookupByLibrary.simpleMessage("ノード"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "この外部リソースはテキストファイルではありません",
    ),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notRunning": MessageLookupByLibrary.simpleMessage("停止中"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループは選択できません",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("同期間隔（分）"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "NTP を有効にすると、システムクロックではなく NTP サーバーから時刻を取得します。",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルを追加して始めましょう",
    ),
    "nullTip": m88,
    "numberRangeTip": m89,
    "numberTip": m90,
    "obfs": MessageLookupByLibrary.simpleMessage("難読化"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("難読化ホスト"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("難読化モード"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("難読化パラメータ"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("難読化パスワード"),
    "onDemand": MessageLookupByLibrary.simpleMessage("オンデマンド"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "オンデマンドは、除外した Wi-Fi に接続している間プロキシを一時停止します。",
    ),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "プロキシトラフィックのみ集計",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("任意"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者"),
    "outbound": MessageLookupByLibrary.simpleMessage("アウトバウンド"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("出口"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("アウトバウンド IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("宛先を上書き"),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "宛先を上書きすると、元のアドレスではなく検出したドメインに接続します。",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("上書き項目"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("純粋なIPを解析"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "純粋な IP を解析すると、IP アドレスしかない接続をスニッフィングします。",
    ),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "peers": MessageLookupByLibrary.simpleMessage("ピア"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("アルバムから選択"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("最前面に固定"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("WebDAVを連携してください"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコードをアップロードしてください",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("プラグイン"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("プラグインホスト"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("プラグインモード"),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portHopping": MessageLookupByLibrary.simpleMessage("ポートホッピング"),
    "portTip": m91,
    "portValue": m92,
    "ports": MessageLookupByLibrary.simpleMessage("ポート"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("事前共有鍵"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("前提条件"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーの組み合わせを押してください"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("前の一致"),
    "privateKey": MessageLookupByLibrary.simpleMessage("秘密鍵"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage("秘密鍵のパスフレーズ"),
    "process": MessageLookupByLibrary.simpleMessage("プロセス"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な間隔を入力してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("自動更新間隔を入力してください"),
    "profileDaysLeft": m93,
    "profileExpiresIn": m94,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されています。自動更新を無効にしますか？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル名を入力してください",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "このプロファイルにのみ適用されます。追加していない項目はデフォルト値を使用します。",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "このプロファイルにのみ適用され、ネットワーク設定の TUN 上書き項目より優先されます。",
    ),
    "profileUpdatedAt": m95,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルURLを入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルのURLを入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイルの並べ替え"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "protocol": MessageLookupByLibrary.simpleMessage("プロトコル"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("プロトコルパラメータ"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("プロトコルバージョン"),
    "providerInUse": m96,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage("リモートリソースのみ対応しています"),
    "providers": MessageLookupByLibrary.simpleMessage("外部リソース"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesCount": m97,
    "proxiesProfileLabel": m98,
    "proxiesRemovedTip": m99,
    "proxiesReplacedTip": m100,
    "proxyChains": MessageLookupByLibrary.simpleMessage("プロキシチェーン"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("プロキシグループが空です"),
    "proxyGroupInUse": m101,
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "起動するとここにグループが表示されます",
    ),
    "proxyGroupsCount": m102,
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyType": MessageLookupByLibrary.simpleMessage("プロキシタイプ"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("キャッシュを整理"),
    "publicKey": MessageLookupByLibrary.simpleMessage("公開鍵"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("ピュアブラック"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("ピュアブラックモード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "QRコードをスキャンしてプロファイルを取得します",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("クイック操作"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("クイック編集"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("最近のリクエスト"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("おすすめ"),
    "recordType": MessageLookupByLibrary.simpleMessage("レコードタイプ"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "regex": MessageLookupByLibrary.simpleMessage("正規表現"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("メモリを解放"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "メモリの解放に失敗しました",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("リモート宛先"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage("リモート DNS 解決"),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("名前を変更"),
    "replace": MessageLookupByLibrary.simpleMessage("置換"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("すべて置換"),
    "request": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage("リクエストと更新"),
    "required": MessageLookupByLibrary.simpleMessage("必須"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "このページには変更があります。リセットしてもよろしいですか？",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットしてもよろしいですか？"),
    "resourceChangedTip": MessageLookupByLibrary.simpleMessage(
      "リソースが変更されました。再読み込みしてからもう一度お試しください。",
    ),
    "resourceLibraryHint": MessageLookupByLibrary.simpleMessage(
      "リソースはライブラリに保存されます。「現在のプロファイルにリソースを適用」で選択してください。",
    ),
    "resourceSelectionHint": MessageLookupByLibrary.simpleMessage(
      "保存したリソースはライブラリに追加されます。このプロファイルで使うリソースを選択してください。選択したノードとフィルターグループは選択グループに追加されます。",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔は0より大きくしてください",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルールに従う"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "ルールに従うを有効にすると DNS 接続がルールに従います。Proxy Server Nameserver の設定が必要です。",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("応答コード"),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("コアを再起動してもよろしいですか？"),
    "restore": MessageLookupByLibrary.simpleMessage("復元"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("すべてのデータを復元"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("プロファイルのみ復元"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("復元方式"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("互換"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("上書き"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("復元が完了しました"),
    "result": MessageLookupByLibrary.simpleMessage("結果"),
    "retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage("ルート除外アドレス"),
    "routerAgentUnavailable": MessageLookupByLibrary.simpleMessage(
      "ルーターのサービスに接続できません。サービスを確認して再試行してください。",
    ),
    "routerBusy": MessageLookupByLibrary.simpleMessage(
      "別の操作を実行中です。しばらくお待ちください。",
    ),
    "routerIconsHint": MessageLookupByLibrary.simpleMessage(
      "キーにグループ名、値に HTTP(S) 画像 URL を入力します。",
    ),
    "routerOperationFailed": MessageLookupByLibrary.simpleMessage(
      "操作を完了できませんでした。ルーターのログを確認して再試行してください。",
    ),
    "routerResourcesHint": MessageLookupByLibrary.simpleMessage(
      "追加ルールは購読ルールより先に適用されます。カスタムノードとフィルターグループは選択グループに追加されます。ノードとルールプロバイダーは Mihomo YAML 形式です。",
    ),
    "routerScriptHint": MessageLookupByLibrary.simpleMessage(
      "main(config) を定義し、変更した設定を返します。スクリプトはルーター上で実行され、制限時間は3秒です。ネットワークとファイル API は利用できません。",
    ),
    "routerServiceConflict": MessageLookupByLibrary.simpleMessage(
      "別のプロキシが必要なネットワークリソースを使用しています。停止してから iPing に接続してください。",
    ),
    "routerSettingsHint": MessageLookupByLibrary.simpleMessage(
      "設定はルーターに保存されます。適用時に iPing コアが再起動し、接続が一時的に切れる場合があります。",
    ),
    "routingMark": MessageLookupByLibrary.simpleMessage("ルーティングマーク"),
    "ru": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("論理ルール AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("完全なドメインにマッチ"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインキーワードにマッチ",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインの正規表現でマッチ",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインサフィックスにマッチ",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "ワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "DSCPマークにマッチ（tproxy udpインバウンドのみ）",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "宛先ポート範囲にマッチ",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage("IPの国コードにマッチ"),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Geosite 内のドメインにマッチ",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("インバウンド名にマッチ"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドポートにマッチ",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドタイプにマッチ",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドユーザー名にマッチ（/ で複数指定可）",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "IPが属するASNにマッチ",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲にマッチ（IP-CIDR6 は別名です）",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲にマッチ",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "IPサフィックス範囲にマッチ",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのリクエストにマッチ（条件不要）",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "TCPまたはUDPにマッチ",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("論理ルール NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("論理ルール OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名でマッチ（Androidではパッケージ名にマッチ）",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名の正規表現でマッチ（Androidではパッケージ名にマッチ）",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名のワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスのフルパスでマッチ",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパスの正規表現でマッチ",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパスのワイルドカードでマッチ（* と ? のみ対応）",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "再マッチ名にマッチ（複数は / で区切る）",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "ルールセットを参照します。rule-providersの設定が必要です",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPの国コードにマッチ",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPが属するASNにマッチ",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPアドレス範囲にマッチ",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPサフィックス範囲にマッチ",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "送信元ポート範囲にマッチ",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "サブルールへマッチします。括弧の使い方に注意してください",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "LinuxのユーザーIDにマッチ",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("ルールが空です"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "ルールは 1 項目に 1 つのルールを書いた YAML リストにしてください。例：- DOMAIN,example.com,DIRECT",
    ),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent を直接接続",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "DNS over TLS をブロック",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "プロキシのループバックを防止",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("QUIC をブロック"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("STUN をブロック"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN 直接接続"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple と Microsoft に直接接続",
    ),
    "ruleProviderBehavior": MessageLookupByLibrary.simpleMessage("ルールの種類"),
    "ruleProviderFormat": MessageLookupByLibrary.simpleMessage("形式"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("ルールセット"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "ルールセットに使用できるエントリがありません",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "この mrs ファイルを読み込めません",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "ルールセットにドメインと IP 範囲が混在しているため、種類を判別できません",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルールターゲット"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "ルールは対応する種類で始めてください。例：DOMAIN,example.com,DIRECT",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("ルール"),
    "rulesCount": m103,
    "runTime": MessageLookupByLibrary.simpleMessage("稼働時間"),
    "running": MessageLookupByLibrary.simpleMessage("実行中"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("ランタイム設定"),
    "safeMode": MessageLookupByLibrary.simpleMessage("セーフモード"),
    "safeModeAppTitle": m104,
    "saturation": MessageLookupByLibrary.simpleMessage("彩度"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "スクリプトモード：拡張スクリプトでプロファイル全体を書き換えます",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("選択項目へスクロール"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m105,
    "secretKey": MessageLookupByLibrary.simpleMessage("キー"),
    "sectionsInEffect": m106,
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("ルールセットを選択してください"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "振り分け戦略を選択してください",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "server": MessageLookupByLibrary.simpleMessage("サーバー"),
    "serviceAbnormalCount": m107,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("すべて利用可能"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("利用可能"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("ブロック済み"),
    "serviceCheck": MessageLookupByLibrary.simpleMessage("検査"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("すべて検査"),
    "serviceCheckedAt": m108,
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("近日提供予定"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "許可されていない ISP",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("検出に失敗しました"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("サービスを管理"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage("オリジナル作品のみ"),
    "servicePending": MessageLookupByLibrary.simpleMessage("未検査"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("アクセス制限"),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "ダッシュボードに表示",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("サービスの状態"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("利用不可"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage("対象外の地域"),
    "services": MessageLookupByLibrary.simpleMessage("サービス"),
    "settingEntries": MessageLookupByLibrary.simpleMessage("設定項目"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "settingsCount": m109,
    "shareLinkUnreadable": m110,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "リンクからプロキシを読み取れませんでした",
    ),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "showLess": MessageLookupByLibrary.simpleMessage("折りたたむ"),
    "showMore": MessageLookupByLibrary.simpleMessage("展開"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "通知に停止ボタンを表示",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("パスワードを表示"),
    "sidebarBlur": MessageLookupByLibrary.simpleMessage("サイドバーのぼかし"),
    "sidebarBlurDesc": MessageLookupByLibrary.simpleMessage(
      "ウィンドウ背後のデスクトップをぼかしてサイドバーに透過します",
    ),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("サイレント起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "サイレント起動ではウィンドウを表示しません。",
    ),
    "singleAdd": MessageLookupByLibrary.simpleMessage("個別追加"),
    "singleImport": MessageLookupByLibrary.simpleMessage("個別インポート"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "ここにはリンクを 1 つだけ入力してください。複数の場合は一覧のクイック編集を使ってください",
    ),
    "singleValueTip": m111,
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("証明書の検証をスキップ"),
    "skipDomain": MessageLookupByLibrary.simpleMessage("スキップするドメイン"),
    "skipDomainDesc": MessageLookupByLibrary.simpleMessage(
      "スキップするドメインにあるドメインを検出しても使用しません。",
    ),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("スキップする宛先アドレス"),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("スキップする送信元アドレス"),
    "slide": MessageLookupByLibrary.simpleMessage("スライド"),
    "sliders": MessageLookupByLibrary.simpleMessage("スライダ"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("プロトコル"),
    "sniffer": MessageLookupByLibrary.simpleMessage("スニッファー"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "スニッファーは TLS・HTTP・QUIC の通信からドメインを読み取り、ルールで照合できるようにします。",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("SOCKSポート"),
    "softStyle": MessageLookupByLibrary.simpleMessage("ソフト"),
    "sort": MessageLookupByLibrary.simpleMessage("並べ替え"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊プロキシ"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊ルール"),
    "spectrum": MessageLookupByLibrary.simpleMessage("スペクトル"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("速度統計"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("振り分け戦略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "振り分け戦略は空にできません",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDが空です"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("スタックトレース"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "標準モード：プロファイルにルールを追加します",
    ),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("最初から作成"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPNを起動しています…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage("起動とバックグラウンド"),
    "status": MessageLookupByLibrary.simpleMessage("状態"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "DNS を無効にすると、システム DNS を使用します。",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPNを停止しています…"),
    "strategy": MessageLookupByLibrary.simpleMessage("戦略"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("厳格なルーティング"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "厳格なルーティングは DNS などの通信が TUN を迂回するのを防ぎます。IPv6 がオフの場合、この端末の IPv6 通信は遮断されます。",
    ),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("サブスクリプション情報"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage("sudo のパスワードを入力"),
    "suspended": MessageLookupByLibrary.simpleMessage("一時停止中…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("プロファイルを切り替え"),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage("アイコンをタップして再試行"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("タップして許可"),
    "target": MessageLookupByLibrary.simpleMessage("宛先"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP同時接続"),
    "testInterval": MessageLookupByLibrary.simpleMessage("テスト間隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("テストURL"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用時にテスト"),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストの拡大縮小"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "アプリ内の文字はこの大きさで表示されます",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "tight": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "time": MessageLookupByLibrary.simpleMessage("時刻"),
    "timeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("ティント"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "toggle": MessageLookupByLibrary.simpleMessage("切り替え"),
    "tolerance": MessageLookupByLibrary.simpleMessage("許容値"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "torch": MessageLookupByLibrary.simpleMessage("ライト"),
    "total": MessageLookupByLibrary.simpleMessage("合計"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("ダウンロード量"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("合計トラフィック"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("アップロード量"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxyポート"),
    "traffic": MessageLookupByLibrary.simpleMessage("通信量"),
    "trafficPeak": m112,
    "trafficTotal": m113,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック統計"),
    "transport": MessageLookupByLibrary.simpleMessage("トランスポート"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "TUN の権限を取得できなかったため、オフにしました。",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage("TUN は管理者モードでのみ有効です。"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "ここで追加した項目は、すべてのプロファイルの TUN 設定を上書きします。追加していない項目はプロファイル自身の設定のままです。カスタムプロファイル自身が追加した項目が優先されます。",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("オフにする"),
    "turnOn": MessageLookupByLibrary.simpleMessage("オンにする"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP リレーモード"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP タイムアウト"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "UDP タイムアウトは秒単位で、gvisor・system・mixed スタックでのみ有効です。",
    ),
    "ultra": MessageLookupByLibrary.simpleMessage("最高"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("不明なネットワークエラー"),
    "unmaximize": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unnamed": MessageLookupByLibrary.simpleMessage("名称未設定"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("固定を解除"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("アップロード帯域幅"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlTip": m114,
    "useHosts": MessageLookupByLibrary.simpleMessage("Hostsを使用"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムのHostsを使用"),
    "usedShort": MessageLookupByLibrary.simpleMessage("使用済み"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("使用済みトラフィック"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("ユーザー名"),
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("仮想 IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("ビビッド"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN関連の設定変更を検出しました",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VPN は VpnService でシステムの全トラフィックを自動的にルーティングします。",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("システムに書き込む"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "システムに書き込むを有効にするとシステムクロックも設定します。Android では無視されます。",
    ),
    "yearsAgo": m115,
    "yearsAgoShort": m116,
    "yes": MessageLookupByLibrary.simpleMessage("はい"),
    "zhCN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
  };
}
