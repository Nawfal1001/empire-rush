extends Node

# Empire Rush AdMob configuration.
# App ID: ca-app-pub-7670901970366595~1941761842
# Rewarded: ca-app-pub-7670901970366595/4376353493
# Interstitial: ca-app-pub-7670901970366595/4208832534

const ADMOB_APP_ID := "ca-app-pub-7670901970366595~1941761842"
const REWARDED_AD_UNIT_ID := "ca-app-pub-7670901970366595/4376353493"
const INTERSTITIAL_AD_UNIT_ID := "ca-app-pub-7670901970366595/4208832534"

var rewarded_ready := false
var interstitial_ready := false
var interstitial_counter := 0

func _ready() -> void:
    # The SDK adapter is intentionally optional so the offline game remains
    # fully playable when no advertising plugin is present.
    pass

func request_rewarded() -> bool:
    return rewarded_ready

func request_interstitial() -> bool:
    return interstitial_ready

func mark_interstitial_session() -> bool:
    interstitial_counter += 1
    # Show only at a natural break and never more often than every 3 sessions.
    if interstitial_counter >= 3:
        interstitial_counter = 0
        return true
    return false
