# Google Flow cinematic production pack | بستهٔ تولید سینمایی با Google Flow

**Status:** production plan and prompts only. No Google Flow generation has been run by this repository or by CI.

**وضعیت:** این سند شامل طرح تولید و پرامپت‌های آماده است؛ هیچ ویدئویی از داخل مخزن یا CI گوگل فلو تولید نشده است.

## Goal | هدف

Create a first **30-second, 16:9 cinematic teaser** for Divslayer, then optionally cut a vertical social version. The teaser should communicate the game's Persian-mythology / Shahnameh-inspired action-RPG identity without inventing unconfirmed characters, boss names, weapons, abilities, locations, or gameplay systems.

ابتدا یک تیزر سینمایی **۳۰ ثانیه‌ای با نسبت ۱۶:۹** بسازید و در صورت نیاز بعداً نسخهٔ عمودی شبکه‌های اجتماعی را تدوین کنید. ویدئو باید هویت اکشن-RPG اسطوره‌ای ایرانی و شاهنامه‌ای Divslayer را منتقل کند، بدون آنکه شخصیت، نام باس، سلاح، توانایی، مکان یا مکانیک تأییدنشده‌ای را به‌عنوان واقعیت بازی معرفی کند.

This is a proposed campaign art direction, not a statement that every colour, environment, or cinematic effect already exists in the game.

این سبک بصری، پیشنهاد هنری برای تیزر است و به معنی وجود همهٔ رنگ‌ها، محیط‌ها یا جلوه‌های سینمایی در نسخهٔ فعلی بازی نیست.

## 1. Prepare the reference | آماده‌سازی مرجع

1. Open [Google Flow](https://labs.google/fx/tools/flow) and create a project named **Divslayer — First Cinematic Teaser**.
2. Use the existing protagonist artwork as a visual reference: [warrior_starter.png](../assets/art/Heroes/warrior_starter.png).
3. The source artwork is a sprite sheet, not a cinematic portrait. For the best character consistency, crop **one clear frame/cell** from it and use that single frame as the character ingredient. Do not upload a contact sheet of multiple unrelated characters.
4. In Flow, select **Video** and add the cropped character image as an **Ingredient/reference** for every shot containing the hero. Keep using the same reference in all hero shots.
5. Choose a landscape **16:9** output and a clip length around **5–6 seconds** (or the closest duration offered by the model in your account). Generate one output per shot for the first pass.

۱. وارد [Google Flow](https://labs.google/fx/tools/flow) شوید و پروژه‌ای با نام **Divslayer — First Cinematic Teaser** بسازید.
۲. از تصویر موجود قهرمان به‌عنوان مرجع ظاهری استفاده کنید: [warrior_starter.png](../assets/art/Heroes/warrior_starter.png).
۳. فایل اصلی یک Sprite Sheet است، نه پرترهٔ سینمایی. برای ثبات بهتر، فقط **یک فریم واضح** از آن را جدا و همان تصویر تکی را به‌عنوان Ingredient اضافه کنید؛ تصویر چندفریمی را به‌عنوان عکس مستقل شخصیت استفاده نکنید.
۴. در Flow حالت **Video** را انتخاب کنید و تصویر برش‌خوردهٔ شخصیت را برای تمام نماهایی که قهرمان در آن حضور دارد به‌عنوان **Ingredient/reference** اضافه کنید. در همهٔ نماهای قهرمان همان مرجع را نگه دارید.
۵. خروجی افقی **۱۶:۹** و طول تقریبی **۵ تا ۶ ثانیه** (یا نزدیک‌ترین مدت موجود در مدل حساب) را انتخاب کنید. برای مرحلهٔ اول از هر نما یک خروجی بسازید.

### Proposed model choice | انتخاب مدل پیشنهادی

Use the newest Flow video model that supports **Ingredients/references** in your account. Google's current help pages describe **Gemini Omni Flash 1.2** as a current option for video generation and editing; model availability and options can vary by account and region. Check the active model and credit cost in Flow before generating. If Omni Flash 1.2 is not offered, use another currently available model that explicitly supports Ingredients.

از جدیدترین مدل ویدئویی Flow که در حساب شما از **Ingredients/references** پشتیبانی می‌کند استفاده کنید. راهنمای فعلی گوگل از **Gemini Omni Flash 1.2** به‌عنوان یکی از گزینه‌های فعلی تولید و ویرایش ویدئو نام می‌برد؛ مدل‌ها و قابلیت‌های قابل مشاهده ممکن است با حساب و منطقه متفاوت باشند. پیش از تولید، مدل فعال و هزینهٔ اعتبار را در خود Flow بررسی کنید. اگر Omni Flash 1.2 در دسترس نبود، مدلی را انتخاب کنید که پشتیبانی از Ingredients در تنظیماتش صریحاً مشخص شده باشد.

## 2. Shared visual direction | دستور بصری مشترک

Append this direction to each prompt below. The individual prompts already include the important constraints, so it is also acceptable to paste each prompt as-is.

این جهت‌گیری بصری را به تمام پرامپت‌های زیر اضافه کنید. محدودیت‌های اصلی در خود پرامپت‌ها نیز آمده‌اند، بنابراین می‌توانید هر پرامپت را همان‌طور که نوشته شده وارد کنید.

> Premium cinematic trailer for a dark Persian-mythic action RPG; Iranian epic-fantasy atmosphere, monumental ancient stone architecture, weathered bronze details, charcoal shadows, restrained lapis-blue accents, wind-blown dust, dramatic but readable lighting, painterly realism with believable materials, powerful clean silhouettes, deliberate camera movement, coherent geography, polished game-cinematic quality. Preserve the uploaded hero reference exactly as the identity guide. No modern objects, no firearms, no cyberpunk elements, no gore, no extra limbs, no duplicated people, no costume redesign, no readable text, no subtitles, no logos, no watermark. No dialogue, no lyrics, and no background music; keep only subtle environmental ambience.

## 3. Six-shot teaser | تیزر شش‌نما

Generate each shot as a separate clip. Use the same hero ingredient in shots 2, 3, 4, and 6. Shot 5 deliberately keeps the enemy mostly in silhouette so it does not establish an unapproved boss design.

هر نما را به‌صورت یک کلیپ جداگانه تولید کنید. در نماهای ۲، ۳، ۴ و ۶ از همان Ingredient قهرمان استفاده کنید. در نمای ۵ دشمن عمداً بیشتر در سایه باقی می‌ماند تا طراحی تأییدنشده‌ای را به‌عنوان طراحی قطعی باس ثبت نکند.

### Shot 01 — The forgotten realm | سرزمین فراموش‌شده

**Purpose:** Establish the world and mood.  
**Suggested length:** 5–6 seconds.

```text
A single cinematic aerial establishing shot over a vast ancient Persian-mythic mountain realm at first light. Monumental weathered stone ruins and a distant fortress sit between rugged mountains; a thin layer of mist moves through the valleys and fine dust catches the low golden sunrise. The camera makes a slow, stable forward push, revealing the scale of the forgotten realm. No people are visible. Premium dark fantasy game-cinematic realism, restrained bronze and charcoal palette with subtle lapis-blue accents. Keep the geography coherent and the architecture grounded. No text, no symbols, no flags, no modern objects, no music, no dialogue.
```

### Shot 02 — The hero appears | ظهور قهرمان

**Purpose:** Introduce the protagonist using the existing game character as the identity reference.  
**Suggested length:** 5–6 seconds. **Attach the same single-frame hero ingredient.**

```text
Use the uploaded warrior image as the exact character identity reference. Create a cinematic, believable high-detail interpretation of that same hero without changing the face, hair, outfit, armour, proportions, silhouette, colours, or equipment shown in the reference. The lone warrior stands on an ancient stone overlook above the ruined Persian-mythic realm. Wind moves only loose fabric and dust. Begin in a medium rear three-quarter shot, then make a slow controlled camera arc that reveals the hero's silhouette against the dawn. The hero remains calm and determined; no attack and no new props. Preserve the reference design; do not invent armour pieces or a different weapon. No text, no logo, no dialogue, no music.
```

### Shot 03 — Into the ruins | ورود به ویرانه‌ها

**Purpose:** Move from atmosphere into adventure.  
**Suggested length:** 5–6 seconds. **Attach the same single-frame hero ingredient.**

```text
Use the uploaded warrior image as the exact protagonist identity reference and preserve the same appearance and equipment. The warrior walks forward through a monumental ancient stone passage leading toward a ruined fortress courtyard. Loose dust drifts across the floor; a few small stones shift under the hero's steps. The camera tracks backward smoothly at waist height, keeping the hero centred and clearly readable. One continuous walking action only, natural body mechanics, no sudden cuts, no additional characters, no combat, no new weapons, no costume changes. Persian-mythic dark fantasy game-cinematic realism. No readable writing, no logos, no dialogue, no background music.
```

### Shot 04 — The first strike | نخستین ضربه

**Purpose:** Show the game's action-RPG energy without fabricating a named skill.  
**Suggested length:** 5–6 seconds. **Attach the same single-frame hero ingredient.**

```text
Use the uploaded warrior image as the exact protagonist reference. Preserve the hero's outfit, body proportions, silhouette, colours, and existing equipment. In a ruined stone courtyard, the warrior performs one clean, decisive combat movement against an indistinct shadowy threat entering the edge of frame. Show one readable action: a short step, one committed strike using only the equipment visible in the reference, then a stable finishing stance. The camera performs a restrained lateral tracking move and a brief impact-time slowdown; small dust and stone particles react to the impact. Keep the enemy mostly obscured and do not invent a named ability or magical effect. No blood, no gore, no extra limbs, no duplicate characters, no text, no dialogue, no music.
```

### Shot 05 — Something awakens | بیدارشدن نیرویی تاریک

**Purpose:** Tease a major threat without defining an unapproved boss.  
**Suggested length:** 5–6 seconds. **No hero ingredient required.**

```text
Inside a vast ancient fortress hall, an enormous unidentified hostile silhouette slowly emerges behind drifting dust and deep shadow. The figure is only partially visible: scale and presence matter more than anatomy. A few dim points of reflected light reveal the scale of the stone chamber; loose dust falls from the ceiling as the unseen presence moves. The camera starts low behind broken stone in the foreground and slowly tilts upward, ending on the immense silhouette. Keep the creature design deliberately obscured and generic; do not depict a recognisable mythological character, a named boss, or a specific creature species. Ominous Persian-mythic dark fantasy atmosphere, no gore, no text, no logo, no dialogue, no music.
```

### Shot 06 — The vow | سوگند

**Purpose:** End on a strong hero image with clean space for the real game title.  
**Suggested length:** 5–6 seconds. **Attach the same single-frame hero ingredient.**

```text
Use the uploaded warrior image as the exact hero identity reference. Preserve the character design, clothing, armour, colours, proportions, silhouette, and equipment. The warrior stands on a high ancient stone ridge, seen in a strong three-quarter rear silhouette, facing the distant ruined fortress and the barely visible dark threat on the horizon. The wind moves dust and loose fabric; dawn light breaks through heavy clouds behind the mountains. The camera makes a slow, confident push toward the hero and then holds. Compose the hero on the left third of the frame and leave uncluttered dark atmospheric negative space on the right for a title to be added later in editing. Do not generate any lettering, symbols, logos, or subtitles. No dialogue, no background music.
```

## 4. Assemble in Flow | مونتاژ در Flow

1. Generate the six clips separately. Review each result before moving on; regenerate only a shot that has a clear character, anatomy, motion, or continuity failure.
2. Add the selected clips to **Scenebuilder** in this order: 01 → 02 → 03 → 04 → 05 → 06.
3. Trim pauses and awkward starts/ends so the final cut is approximately 30 seconds. Use simple cuts or restrained dissolves; avoid excessive transitions.
4. Keep the same grade and audio policy throughout. Do not add generated logos or ask the model to spell “DIVSLAYER”.
5. Download the assembled scene from Flow. Keep the original individual clips as well as the assembled edit.

۱. شش کلیپ را جداگانه تولید کنید و هر نتیجه را پیش از رفتن به نمای بعدی بررسی کنید؛ فقط نمایی را دوباره بسازید که ایراد واضح در هویت شخصیت، آناتومی، حرکت یا پیوستگی دارد.
۲. کلیپ‌های انتخاب‌شده را در **Scenebuilder** با این ترتیب قرار دهید: ۰۱ ← ۰۲ ← ۰۳ ← ۰۴ ← ۰۵ ← ۰۶.
۳. مکث‌ها و شروع/پایان نامناسب را ببُرید تا تدوین نهایی حدود ۳۰ ثانیه شود. از برش ساده یا محوشدن محدود استفاده کنید و از گذارهای نمایشی بیش‌ازحد پرهیز کنید.
۴. رنگ و سیاست صوتی را در تمام نماها هماهنگ نگه دارید. لوگوی تولیدشده اضافه نکنید و از مدل نخواهید عبارت «DIVSLAYER» را بنویسد.
۵. صحنهٔ مونتاژشده را از Flow دریافت کنید و کلیپ‌های اصلی را نیز جداگانه نگه دارید.

Google Flow supports text-to-video, image/reference ingredients, start/end frames, and arranging/trimming clips in Scenebuilder. Some features and models vary by plan and region; use the controls currently shown in your account.

گوگل فلو از تولید ویدئو با متن، Ingredientهای تصویری/مرجع، فریم آغاز و پایان، و چیدن و کوتاه‌کردن کلیپ‌ها در Scenebuilder پشتیبانی می‌کند. بعضی قابلیت‌ها و مدل‌ها با توجه به طرح اشتراک و منطقه فرق می‌کنند؛ کنترل‌های قابل مشاهده در حساب خودتان را ملاک قرار دهید.

## 5. Review before publishing | بازبینی پیش از انتشار

- [ ] The hero is recognisably based on the uploaded game reference in every hero shot.
- [ ] No invented weapon, skill, boss name, dialogue, or gameplay feature is presented as official game content.
- [ ] No broken anatomy, extra fingers/limbs, duplicate hero, flickering costume, or impossible movement.
- [ ] No generated text, fake UI, watermark, or unapproved logo appears.
- [ ] Audio is either removed or reviewed separately; do not reuse the unapproved LMMS title-theme sketch as final music.
- [ ] Check Google Flow's current terms, model-specific restrictions, and the rights to every uploaded reference before public or commercial use.
- [ ] Keep the downloaded master outside the game asset folders until it has been reviewed and approved.

- [ ] قهرمان در همهٔ نماهای مربوط، به‌وضوح بر اساس مرجع تصویری بازی باشد.
- [ ] هیچ سلاح، مهارت، نام باس، دیالوگ یا قابلیت ساختگی به‌عنوان محتوای رسمی بازی معرفی نشده باشد.
- [ ] نقص آناتومی، انگشت/اندام اضافه، قهرمان تکراری، تغییر ناگهانی لباس یا حرکت غیرممکن وجود نداشته باشد.
- [ ] متن تولیدشده، رابط کاربری جعلی، واترمارک یا لوگوی تأییدنشده دیده نشود.
- [ ] صدا حذف یا جداگانه بررسی شده باشد؛ طرح موسیقی LMMS که هنوز تأیید نشده، نباید به‌عنوان موسیقی نهایی استفاده شود.
- [ ] پیش از استفادهٔ عمومی یا تجاری، شرایط جاری Google Flow، محدودیت‌های مدل و حقوق تمام تصاویر مرجع بارگذاری‌شده بررسی شوند.
- [ ] فایل اصلی دانلودشده تا زمان بررسی و تأیید در پوشه‌های دارایی بازی قرار نگیرد.

## 6. Important production boundary | مرز مهم تولید

A Flow video is a **cinematic video**, not a Godot sprite sheet or a production-ready gameplay animation. Do not replace the game's sprite assets with a trailer frame or import a full promotional MP4 as if it were a character animation. If a clip is later approved for an in-game cutscene, create a separate integration task for format, mobile performance, subtitles, audio, and playback testing.

ویدئوی Flow یک **ویدئوی سینمایی** است، نه Sprite Sheet یا انیمیشن آمادهٔ گیم‌پلی برای Godot. فریم تیزر را جایگزین Spriteهای بازی نکنید و فایل MP4 تبلیغاتی را مانند انیمیشن شخصیت وارد نکنید. اگر بعداً کلیپی برای میان‌پردهٔ داخل بازی تأیید شد، باید کار جداگانه‌ای برای فرمت، کارایی روی موبایل، زیرنویس، صدا و آزمون پخش تعریف شود.

Generated media must not be treated as commercially cleared just because it was successfully generated. Record the actual model, prompt, date, source references, account/plan terms, and approval evidence before promoting any output to the public release.

صرف تولید موفق محتوای هوش مصنوعی به معنی تأیید حقوق استفادهٔ تجاری آن نیست. پیش از انتقال هر خروجی به نسخهٔ عمومی، مدل واقعی، پرامپت، تاریخ، تصاویر مرجع، شرایط حساب/اشتراک و مدرک بررسی و تأیید را ثبت کنید.
