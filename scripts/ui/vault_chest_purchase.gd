class_name VaultChestPurchase
extends RefCounted

## The vault-chest price both "add chest" buttons show and confirm before spending.
## Mirrors the data service's flat CHEST_FAME_COST (PlayerDataService).

const FAME_COST := 7500


static func button_text(label: String) -> String:
	return "%s - %s fame" % [label, Mastery.thousands(FAME_COST)]


static func confirm(popup: ConfirmPopup, service: DataService, on_confirm: Callable) -> void:
	var fame := int(service.account.get("accountFame", 0))
	popup.request("Buy a vault chest for %s fame? You have %s." % [Mastery.thousands(FAME_COST),
		Mastery.thousands(fame)], "Buy", on_confirm)
