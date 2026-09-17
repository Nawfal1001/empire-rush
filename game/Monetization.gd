extends Node

# Empire Rush AdMob configuration.
# App ID: ca-app-pub-7670901970366595~1941761842
# Rewarded: ca-app-pub-7670901970366595/4376353493
# Interstitial: ca-app-pub-7670901970366595/4208832534

const ADMOB_APP_ID := "ca-app-pub-7670901970366595~1941761842"
const REWARDED_AD_UNIT_ID := "ca-app-pub-7670901970366595/4376353493"
const INTERSTITIAL_AD_UNIT_ID := "ca-app-pub-7670901970366595/4208832534"

# Google's official test units are used automatically in debug builds.
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"

var rewarded_ad = null
var interstitial_ad = null
var rewarded_ready := false
var interstitial_ready := false
var session_break_counter := 0

signal rewarded_completed
signal interstitial_closed

func _ready() -> void:
    _initialize_admob()

func _ad_unit_rewarded() -> String:
    return TEST_REWARDED_ID if OS.is_debug_build() else REWARDED_AD_UNIT_ID

func _ad_unit_interstitial() -> String:
    return TEST_INTERSTITIAL_ID if OS.is_debug_build() else INTERSTITIAL_AD_UNIT_ID

func _initialize_admob() -> void:
    # The game remains fully playable if the native advertising SDK is absent.
    if not Engine.has_singleton("MobileAds"):
        return
    var ads = Engine.get_singleton("MobileAds")
    if ads and ads.has_method("initialize"):
        ads.initialize()
    _load_rewarded()
    _load_interstitial()

func _load_rewarded() -> void:
    if not ClassDB.class_exists("RewardedAdLoader"):
        return
    var loader = ClassDB.instantiate("RewardedAdLoader")
    var callback = ClassDB.instantiate("RewardedAdLoadCallback")
    if loader == null or callback == null:
        return
    callback.on_ad_loaded = _on_rewarded_loaded
    callback.on_ad_failed_to_load = _on_rewarded_failed
    loader.load(_ad_unit_rewarded(), ClassDB.instantiate("AdRequest"), callback)

func _load_interstitial() -> void:
    if not ClassDB.class_exists("InterstitialAdLoader"):
        return
    var loader = ClassDB.instantiate("InterstitialAdLoader")
    var callback = ClassDB.instantiate("InterstitialAdLoadCallback")
    if loader == null or callback == null:
        return
    callback.on_ad_loaded = _on_interstitial_loaded
    callback.on_ad_failed_to_load = _on_interstitial_failed
    loader.load(_ad_unit_interstitial(), ClassDB.instantiate("AdRequest"), callback)

func _on_rewarded_loaded(ad) -> void:
    rewarded_ad = ad
    rewarded_ready = true

func _on_rewarded_failed(error) -> void:
    rewarded_ad = null
    rewarded_ready = false

func _on_interstitial_loaded(ad) -> void:
    interstitial_ad = ad
    interstitial_ready = true

func _on_interstitial_failed(error) -> void:
    interstitial_ad = null
    interstitial_ready = false

func request_rewarded() -> bool:
    if rewarded_ad == null or not rewarded_ready:
        _load_rewarded()
        return false

    var listener = null
    if ClassDB.class_exists("OnUserEarnedRewardListener"):
        listener = ClassDB.instantiate("OnUserEarnedRewardListener")
        if listener:
            listener.on_user_earned_reward = _on_user_earned_reward

    if listener:
        rewarded_ad.show(listener)
    else:
        rewarded_ad.show()

    rewarded_ready = false
    rewarded_ad = null
    _load_rewarded()
    return true

func _on_user_earned_reward(reward) -> void:
    rewarded_completed.emit()

func request_interstitial() -> bool:
    if interstitial_ad == null or not interstitial_ready:
        _load_interstitial()
        return false
    interstitial_ad.show()
    interstitial_ready = false
    interstitial_ad = null
    _load_interstitial()
    interstitial_closed.emit()
    return true

func mark_interstitial_session() -> bool:
    session_break_counter += 1
    # Interstitials are reserved for natural breaks and never interrupt a turn.
    if session_break_counter >= 3:
        session_break_counter = 0
        return request_interstitial()
    return false

func can_reward() -> bool:
    return rewarded_ready
