extends "res://scripts/game.gd"

var rehearsal=false

func save_game():
 if not rehearsal:super.save_game()

var practice_stage := ""
var portrait_studio

func pahlavan_portrait() -> Texture2D:
 if not is_instance_valid(portrait_studio):
  portrait_studio=preload("res://visual3d/stage.gd").new()
  add_child(portrait_studio)
  portrait_studio.hide()
  portrait_studio.studio(Vector2i(192,192),1.05,Vector3(0,1.65,0),0.45)
  var figure=preload("res://visual3d/hero.scn").instantiate()
  portrait_studio.stage.add_child(figure)
  figure.rotation.y=-0.22
  portrait_studio.vp.render_target_update_mode=SubViewport.UPDATE_ONCE
 return portrait_studio.texture

func objective() -> String:
 if rehearsal:
  match practice_stage:
   "ForestQuickStart":
    if state.get("ash_wheel_encounter",false):return t("Caravan ambush complete.", "تمرین کمین کاروان تمام شد.")
    return t("Inspect the wheel and step away from the cart.", "چرخ را بررسی کن و از گاری فاصله بگیر.")
   "CryptQuickStart":
    if state.get("ember_echo_solved",false):return t("Echo seal lit.", "مُهر پژواک روشن شد.")
    return t("Watch the stones and repeat their order.", "سنگ‌ها را ببین و به همان ترتیب رویشان قدم بگذار.")
   "DuelQuickStart":
    if is_defeated("boss"):return t("Arzhang defeated.", "ارژنگ شکست خورد.")
    return t("Lure Arzhang into the pillars.", "ارژنگ را به سوی ستون‌ها بکشان.")
 return super.objective()
