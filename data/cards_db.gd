extends RefCounted

const DEFS := {
	"C01": {"name": "スピンソード", "detail": "周囲を回転する刃\n新規取得 / 取得済みは強化", "kind": "weapon"},
	"C02": {"name": "ストレートショット", "detail": "前方に弾を発射\n新規取得 / 取得済みは強化", "kind": "weapon"},
	"C03": {"name": "ホーミングミサイル", "detail": "敵を追尾する弾\n新規取得 / 取得済みは強化", "kind": "weapon"},
	"C04": {"name": "チェインライトニング", "detail": "敵の間で連鎖する落雷\n新規取得 / 取得済みは強化", "kind": "weapon"},
	"C05": {"name": "フレイムスロワー", "detail": "照準方向に火炎放射\n新規取得 / 取得済みは強化", "kind": "weapon"},
	"C06": {"name": "オービットボム", "detail": "爆弾を投下し範囲爆発\n新規取得 / 取得済みは強化", "kind": "weapon"},
	"C07": {"name": "アタックUP", "detail": "全武器の攻撃力+20%", "kind": "stat", "max": 5},
	"C08": {"name": "クイックキャスト", "detail": "攻撃間隔-12% (下限-50%)", "kind": "stat", "max": 5},
	"C09": {"name": "マルチショット", "detail": "投射武器の弾数+1", "kind": "stat", "max": 3},
	"C10": {"name": "エリアUP", "detail": "攻撃範囲+25%", "kind": "stat", "max": 5},
	"C11": {"name": "持続UP", "detail": "弾の持続時間+30%", "kind": "stat", "max": 5},
	"C12": {"name": "クリティカル", "detail": "会心率+10% (2倍ダメ)", "kind": "stat", "max": 5},
	"C13": {"name": "弾速UP", "detail": "弾速+30%", "kind": "stat", "max": 5},
	"C14": {"name": "ノックバックUP", "detail": "ノックバック+40%", "kind": "stat", "max": 3},
	"C15": {"name": "スニーカー", "detail": "移動速度+15%", "kind": "stat", "max": 5},
	"C16": {"name": "ハート", "detail": "最大HP+20\nHP20回復", "kind": "stat", "max": 5},
	"C17": {"name": "リジェネ", "detail": "HPが毎秒1.0回復", "kind": "stat", "max": 5},
	"C18": {"name": "アーマー", "detail": "被ダメージ-3 (最小1)", "kind": "stat", "max": 5},
	"C19": {"name": "マグネット", "detail": "宝石回収範囲+50%", "kind": "stat", "max": 5},
	"C20": {"name": "学習装置", "detail": "経験値獲得+25%", "kind": "stat", "max": 5},
}

const WEAPON_IDS := ["C01", "C02", "C03", "C04", "C05", "C06"]
const STAT_IDS := ["C07", "C08", "C09", "C10", "C11", "C12", "C13", "C14", "C15", "C16", "C17", "C18", "C19", "C20"]
const WEAPON_MAX_LEVEL := 8

static func get_def(card_id: String) -> Dictionary:
	return DEFS.get(card_id, {})
