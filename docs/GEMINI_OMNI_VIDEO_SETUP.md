# Gemini Omni video generation | تولید ویدئو با Gemini Omni

This repository includes a **manual, cost-controlled** GitHub Actions workflow for generating one cinematic clip with Google's Gemini Omni 1.2 Flash API.

این مخزن یک گردش‌کار **دستی و کنترل‌شده از نظر هزینه** برای ساخت هر بار یک کلیپ سینمایی با API مدل Gemini Omni 1.2 Flash گوگل دارد.

## What this does | چه کاری انجام می‌دهد؟

- Sends one prompt and, optionally, a reference image to the Gemini Interactions API.
- Optionally crops one cell from the existing 5 × 3 warrior sprite sheet before uploading it as the character reference.
- Requests one video, defaults to 6 seconds / 720p / 16:9, downloads the MP4, and stores it as a GitHub Actions artifact for 14 days.
- Does **not** upload a video automatically into `assets/`, modify the game, or create an APK.

- یک پرامپت و در صورت نیاز یک تصویر مرجع را به Gemini Interactions API می‌فرستد.
- در صورت انتخاب، یک خانه از Sprite Sheet جنگجو با شبکهٔ ۵×۳ جدا می‌کند و فقط همان فریم را به‌عنوان مرجع شخصیت ارسال می‌کند.
- یک ویدئو می‌سازد، به‌صورت پیش‌فرض با مدت ۶ ثانیه، کیفیت 720p و نسبت ۱۶:۹؛ سپس MP4 را دانلود و به‌مدت ۱۴ روز به‌عنوان GitHub Actions Artifact نگه می‌دارد.
- ویدئو را خودکار در `assets/` قرار نمی‌دهد، بازی را تغییر نمی‌دهد و APK نمی‌سازد.

The workflow calls `gemini-omni-1.2-flash` through `POST https://generativelanguage.googleapis.com/v1beta/interactions`. It uses the documented REST response steps and URI-delivery file download flow. New video generation from a reference image is supported.

این گردش‌کار مدل `gemini-omni-1.2-flash` را از طریق endpoint رسمی Interactions فراخوانی می‌کند. پاسخ REST و دانلود URI مطابق نمونه‌های مستندشدهٔ گوگل پردازش می‌شوند. تولید ویدئوی جدید با تصویر مرجع پشتیبانی می‌شود.

## 1. Claim the Google AI Pro developer credit | فعال‌کردن اعتبار توسعه‌دهندگان

1. Sign in to [Google AI Studio](https://aistudio.google.com/) with the **primary Google account** that owns the Google AI Pro subscription.
2. Open the billing / developer credits area and redeem the monthly Google Developer Program credit. An active Google Developer Program profile is required.
3. Link the eligible Cloud Billing account and complete Google's required billing setup.
4. Google states that Gemini API Cloud Billing requires a **$5 minimum prepayment** and balance before promotional credits can be used. This is a billing prerequisite, not an API key and not the same as Flow credits.
5. Create a paid-tier Gemini API key in [AI Studio API keys](https://aistudio.google.com/api-keys). Check the balance and usage in [AI Studio billing](https://aistudio.google.com/billing).

۱. با **حساب اصلی دارندهٔ اشتراک Google AI Pro** وارد [Google AI Studio](https://aistudio.google.com/) شوید.
۲. بخش اعتبار توسعه‌دهندگان / صورتحساب را باز و اعتبار ماهانهٔ Google Developer Program را مطالبه کنید. داشتن پروفایل فعال Developer Program لازم است.
۳. حساب واجدشرایط Cloud Billing را متصل و تنظیم صورتحساب گوگل را کامل کنید.
۴. گوگل برای استفاده از Gemini API با Cloud Billing حداقل **۵ دلار پیش‌پرداخت** و موجودی لازم را اعلام کرده است تا اعتبارهای تبلیغاتی قابل مصرف باشند. این شرط صورتحساب است؛ نه API Key و نه اعتبار Flow.
۵. یک API Key با سطح دسترسی Paid در [AI Studio API keys](https://aistudio.google.com/api-keys) بسازید. اعتبار و مصرف را از [صفحهٔ صورتحساب AI Studio](https://aistudio.google.com/billing) بررسی کنید.

As currently announced by Google, Google AI Pro includes **$10/month in Google Cloud developer credits** through the Google Developer Program. Credits must be claimed and are subject to Google's eligibility, billing, and expiration rules. Do not assume they have already been redeemed in your account.

طبق اعلام فعلی گوگل، Google AI Pro شامل **۱۰ دلار اعتبار ماهانهٔ توسعه‌دهندگان Google Cloud** از طریق Google Developer Program است. اعتبار باید مطالبه شود و تابع شرایط واجدشرایط‌بودن، صورتحساب و تاریخ انقضای گوگل است. فرض نکنید این اعتبار قبلاً در حساب شما فعال شده است.

## 2. Add the API key as a GitHub secret | ذخیرهٔ امن کلید در GitHub

Never paste the API key into chat, a source file, a workflow input, or a commit.

کلید API را هرگز در چت، سورس‌کد، ورودی گردش‌کار یا commit قرار ندهید.

In the Divslayer repository:

1. Open **Settings**.
2. Open **Secrets and variables → Actions**.
3. Select **New repository secret**.
4. Set the name to exactly `GEMINI_API_KEY`.
5. Paste the key into the secret value field and save.

در مخزن Divslayer:

۱. وارد **Settings** شوید.
۲. بخش **Secrets and variables → Actions** را باز کنید.
۳. **New repository secret** را انتخاب کنید.
۴. نام را دقیقاً `GEMINI_API_KEY` قرار دهید.
۵. کلید را فقط در قسمت مقدار Secret وارد و ذخیره کنید.

The workflow has read-only repository permissions. The secret is available only to the manual generation job; pull-request validation does not receive it. The key is sent to Google in the `x-goog-api-key` HTTPS header and is never printed by the script.

گردش‌کار فقط مجوز خواندن مخزن را دارد. Secret فقط در job تولید دستی در دسترس است؛ job بررسی Pull Request آن را دریافت نمی‌کند. اسکریپت کلید را در header امن HTTPS با نام `x-goog-api-key` به گوگل می‌فرستد و هرگز آن را چاپ نمی‌کند.

## 3. Run the generator | اجرای تولیدکننده

After this PR is merged into `main` and the repository secret is saved:

1. Open the repository's **Actions** tab.
2. Select **Gemini Omni video generation**.
3. Choose **Run workflow**.
4. Enter an English prompt. English is currently the fully supported prompting language in the model docs.
5. By default, the workflow uses `assets/art/Heroes/warrior_starter.png` as a character reference and crops cell `0` from its 5 × 3 sprite sheet. You may choose cells `0`–`14`. To use a regular still image instead, provide its repository-relative PNG/JPEG path and turn **Crop sprite sheet** off.
6. Select duration (6 / 10 / 15 seconds), aspect ratio (16:9 / 9:16), and resolution (360p / 720p), then run.

پس از ادغام این PR در `main` و ذخیرهٔ Secret:

۱. زبانهٔ **Actions** مخزن را باز کنید.
۲. **Gemini Omni video generation** را انتخاب کنید.
۳. **Run workflow** را بزنید.
۴. پرامپت را به انگلیسی وارد کنید؛ زبان انگلیسی در مستندات مدل به‌طور کامل پشتیبانی می‌شود.
۵. به‌صورت پیش‌فرض فایل `assets/art/Heroes/warrior_starter.png` مرجع شخصیت است و خانهٔ `0` از شبکهٔ ۵×۳ آن جدا می‌شود. می‌توانید خانه‌های `0` تا `14` را انتخاب کنید. برای استفاده از یک عکس معمولی، مسیر PNG/JPEG آن را در مخزن بدهید و گزینهٔ **Crop sprite sheet** را خاموش کنید.
۶. مدت (۶ / ۱۰ / ۱۵ ثانیه)، نسبت تصویر (۱۶:۹ / ۹:۱۶) و کیفیت (360p / 720p) را انتخاب و اجرا کنید.

The generated MP4 and a JSON metadata file are uploaded as a **14-day artifact**. Download them from the completed workflow run's **Artifacts** section. Each run makes one generation request; the script does not automatically retry a POST after a timeout because doing so could create a second charge.

فایل MP4 و یک فایل JSON حاوی فراداده به‌صورت **Artifact با مهلت نگهداری ۱۴ روزه** بارگذاری می‌شوند. آن‌ها را از بخش **Artifacts** اجرای کامل‌شده دانلود کنید. هر اجرا فقط یک درخواست تولید ارسال می‌کند؛ اسکریپت پس از timeout درخواست POST را خودکار تکرار نمی‌کند، چون ممکن است باعث هزینهٔ دوباره شود.

## 4. Cost controls | کنترل هزینه

Current standard pricing for Gemini Omni 1.2 Flash is approximately:

- 360p: **$0.023 per second**
- 720p: **$0.07 per second**

Approximate video-output costs (before small prompt/reference-image input charges):

| Duration | 360p | 720p |
|---:|---:|---:|
| 6 seconds | $0.14 | $0.42 |
| 10 seconds | $0.23 | $0.70 |
| 15 seconds | $0.35 | $1.05 |

نرخ فعلی استاندارد Gemini Omni 1.2 Flash تقریباً چنین است:

- 360p: **۰٫۰۲۳ دلار به‌ازای هر ثانیه**
- 720p: **۰٫۰۷ دلار به‌ازای هر ثانیه**

هزینه‌های بالا تقریبی‌اند و هزینهٔ کوچک ورودی پرامپت/تصویر مرجع را شامل نمی‌شوند. نرخ‌ها ممکن است تغییر کنند؛ پیش از اجرای تولید، قیمت جاری و ماندهٔ اعتبار را در AI Studio بررسی کنید. در این workflow کیفیت 1080p و 4K عمداً فعال نشده است.

## 5. Divslayer asset rules | قواعد ورود دارایی به بازی

- Treat the first output as a **cinematic review clip**, not a gameplay sprite sheet.
- Do not copy an MP4 into the game's character sprite folders.
- Check character identity, anatomy, motion, costume continuity, visual defects, sound, and rights before approving the clip.
- A video generated from the warrior sprite sheet is a visual interpretation; it does not automatically become a faithful or approved redesign of the in-game character.
- Only after review should a separate PR be created for a Godot cutscene or other runtime integration.
- This workflow creates new video from a prompt and optional image reference. It does not edit or extend an uploaded video.
- Generated videos include invisible SynthID watermarking for provenance verification. This does not itself establish commercial-use clearance.

- خروجی اول یک **کلیپ سینمایی برای بازبینی** است، نه Sprite Sheet گیم‌پلی.
- MP4 را در پوشه‌های Sprite شخصیت بازی کپی نکنید.
- هویت شخصیت، آناتومی، حرکت، پیوستگی لباس، ایرادهای بصری، صدا و حقوق استفاده را پیش از تأیید بررسی کنید.
- ویدئویی که از Sprite Sheet ساخته می‌شود، تفسیر بصری مدل است و به‌خودی‌خود طراحی وفادار یا تأییدشدهٔ شخصیت بازی محسوب نمی‌شود.
- تنها پس از بررسی می‌توان PR جداگانه‌ای برای میان‌پردهٔ Godot یا اتصال به runtime ایجاد کرد.
- این گردش‌کار ویدئوی تازه‌ای را از پرامپت و تصویر مرجع اختیاری می‌سازد؛ ویدئوی بارگذاری‌شده را ویرایش یا ادامه نمی‌دهد.
- ویدئوهای تولیدشده دارای نشان نامرئی SynthID برای بررسی منشأ هستند. این نشان به‌تنهایی مجوز استفادهٔ تجاری را ثابت نمی‌کند.

## Troubleshooting | رفع اشکال

- `GEMINI_API_KEY is not set`: add the repository secret exactly as described above.
- `permission`, `billing`, or `quota` errors: check that the key is paid-tier, the monthly developer credits have been claimed, Cloud Billing is linked, and the account has the required prepayment balance.
- `model not found` or `not available`: verify current model access and billing in AI Studio; this workflow intentionally uses `gemini-omni-1.2-flash`.
- `timed out`: inspect AI Studio's recent activity before starting another run; the request may have reached Google even when the runner timed out.

- خطای `GEMINI_API_KEY is not set`: Secret را دقیقاً با نام گفته‌شده اضافه کنید.
- خطای `permission`، `billing` یا `quota`: پولی‌بودن API Key، مطالبهٔ اعتبار توسعه‌دهندگان، اتصال Cloud Billing و وجود ماندهٔ پیش‌پرداخت را بررسی کنید.
- خطای `model not found` یا `not available`: دسترسی مدل و صورتحساب را در AI Studio بررسی کنید؛ این workflow عمداً از `gemini-omni-1.2-flash` استفاده می‌کند.
- خطای `timed out`: پیش از اجرای دوباره، فعالیت اخیر در AI Studio را بررسی کنید؛ ممکن است درخواست به گوگل رسیده باشد، حتی اگر runner timeout شده باشد.

## Official references | منابع رسمی

- [Gemini Omni video generation and reference images](https://aistudio.google.com/docs/omni)
- [Gemini API pricing](https://aistudio.google.com/docs/pricing#gemini-omni-1.2-flash)
- [Claim Google Cloud credits in AI Studio](https://blog.google/innovation-and-ai/technology/developers-tools/google-cloud-credits-gdp-ai-studio/)
- [Google Developer Program benefits](https://developers.google.com/profile/help/benefits)
