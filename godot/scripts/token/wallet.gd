extends Node
## The player's Solana wallet, in the browser version: connect Phantom (or Solflare,
## Backpack), then read their $GULL balance and how many Gullhaven Fishers they hold,
## straight from the chain. Read-only: the game never asks to move anything.
## The addresses come from res://data/chain.json, written by launch/scripts/status.mjs.
## On desktop there's no wallet (browser wallets live in the browser), so it says so.

signal changed

const CHAIN_PATH := "res://data/chain.json"
const POLL := 0.5

var chain: Dictionary = {}
var state: Dictionary = {"status": "idle", "address": "", "gull": 0.0, "sol": 0.0, "fishers": 0, "error": ""}
var _t := 0.0
var _ready_js := false

# The browser half. Kept here (not in a .js file) so it always ships with the export.
# test/game-wallet.mjs in launch/ runs this same code against a local validator.
const BRIDGE_JS := """
// BRIDGE START
window.gullWallet = window.gullWallet || (function () {
  var s = { status: "idle", address: "", gull: 0, sol: 0, fishers: 0, error: "" };
  var cfg = null;
  function prov() {
    return (window.phantom && window.phantom.solana) || window.solflare || (window.backpack && window.backpack.solana) || window.solana || null;
  }
  async function rpc(method, params) {
    var r = await fetch(cfg.rpc, { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: method, params: params }) });
    var j = await r.json();
    if (j.error) throw new Error(j.error.message);
    return j.result;
  }
  async function refresh() {
    if (!s.address || !cfg || !cfg.rpc) return;
    try {
      if (cfg.gull_mint) {
        var t = await rpc("getTokenAccountsByOwner", [s.address, { mint: cfg.gull_mint }, { encoding: "jsonParsed", commitment: "confirmed" }]);
        s.gull = t.value.reduce(function (sum, a) { return sum + Number(a.account.data.parsed.info.tokenAmount.uiAmount || 0); }, 0);
      }
      if (cfg.fisher_collection) {
        // Metaplex Core assets: byte 0 = AssetV1 (1, "2" in base58), owner at byte 1,
        // update authority = Collection (2, "3") at byte 33, the collection at byte 34
        var f = await rpc("getProgramAccounts", [cfg.core_program, { encoding: "base64", commitment: "confirmed", dataSlice: { offset: 0, length: 0 },
          filters: [{ memcmp: { offset: 0, bytes: "2" } }, { memcmp: { offset: 1, bytes: s.address } },
                    { memcmp: { offset: 33, bytes: "3" } }, { memcmp: { offset: 34, bytes: cfg.fisher_collection } }] }]);
        s.fishers = f.length;
      }
      var b = await rpc("getBalance", [s.address, { commitment: "confirmed" }]);
      s.sol = b.value / 1e9;
      s.error = "";
    } catch (e) {
      s.error = String((e && e.message) || e);
    }
    s.status = "connected";
  }
  return {
    setConfig: function (json) { cfg = JSON.parse(json); },
    hasWallet: function () { return !!prov(); },
    connect: async function () {
      var p = prov();
      if (!p) { s.status = "nowallet"; return; }
      s.status = "connecting"; s.error = "";
      try {
        var r = await p.connect();
        s.address = ((r && r.publicKey) || p.publicKey).toString();
        await refresh();
      } catch (e) { s.status = "idle"; s.error = String((e && e.message) || e); }
    },
    disconnect: async function () {
      try { var p = prov(); if (p && p.disconnect) await p.disconnect(); } catch (e) {}
      s.status = "idle"; s.address = ""; s.gull = 0; s.sol = 0; s.fishers = 0;
    },
    refresh: refresh,
    json: function () { return JSON.stringify(s); },
    open: function (url) { window.open(url, "_blank", "noopener"); }
  };
})();
// BRIDGE END
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps reading while the game menu is open
	chain = load_chain()
	if is_web():
		JavaScriptBridge.eval(BRIDGE_JS, true)
		JavaScriptBridge.eval("window.gullWallet.setConfig(%s)" % JSON.stringify(JSON.stringify(chain)), true)
		_ready_js = true


static func load_chain() -> Dictionary:
	if not FileAccess.file_exists(CHAIN_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAIN_PATH))
	return parsed if parsed is Dictionary else {}


static func is_web() -> bool:
	return OS.has_feature("web")


## Is there anything launched on this network for the wallet to read?
func launched() -> bool:
	return str(chain.get("gull_mint", "")) != "" or str(chain.get("fisher_collection", "")) != ""


func connected() -> bool:
	return str(state.get("address", "")) != ""


func connect_wallet() -> void:
	if _ready_js:
		JavaScriptBridge.eval("window.gullWallet.connect()", true)


func disconnect_wallet() -> void:
	if _ready_js:
		JavaScriptBridge.eval("window.gullWallet.disconnect()", true)


func refresh() -> void:
	if _ready_js:
		JavaScriptBridge.eval("window.gullWallet.refresh()", true)


func open_mint_page() -> void:
	var url := str(chain.get("mint_page_url", ""))
	if url == "":
		return
	if _ready_js:
		JavaScriptBridge.eval("window.gullWallet.open(%s)" % JSON.stringify(url), true)
	else:
		OS.shell_open(url)


## One line for the Harbour page about the wallet.
func summary() -> String:
	if not launched():
		return "Wallet: the coin and the Fishers aren't launched on this network yet."
	if not is_web():
		return "Wallet: play the browser version to connect Phantom and use your on-chain Fishers and $GULL."
	match str(state.status):
		"nowallet":
			return "Wallet: no Solana wallet found in this browser. Install Phantom, then reload."
		"connecting":
			return "Wallet: check Phantom to approve the connection..."
	if not connected():
		return "Wallet: not connected%s." % ((" (%s)" % state.error) if str(state.error) != "" else "")
	var a := str(state.address)
	var text := "Wallet %s...%s on %s: %s $%s, %d Fisher%s, %.3f SOL." % [a.left(4), a.right(4), str(chain.get("network", "?")),
		_num(float(state.gull)), str(chain.get("gull_symbol", "GULL")), int(state.fishers), "" if int(state.fishers) == 1 else "s", float(state.sol)]
	if str(state.error) != "":
		text += " (couldn't read: %s)" % state.error
	return text


static func _num(v: float) -> String:
	if v >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return "%.2f" % v


func _process(delta: float) -> void:
	if not _ready_js:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = POLL
	var got: Variant = JavaScriptBridge.eval("window.gullWallet.json()", true)
	if not (got is String):
		return
	var parsed: Variant = JSON.parse_string(got)
	if not (parsed is Dictionary):
		return
	var was := JSON.stringify(state)
	state = parsed
	if JSON.stringify(state) != was:
		changed.emit()
