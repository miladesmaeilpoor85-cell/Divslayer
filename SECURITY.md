# Security Policy | سیاست امنیت

Do not publish exploitable vulnerabilities, credentials, private user data, or sensitive details in public Issues. Contact the repository owner privately through GitHub's available contact options.

آسیب‌پذیری قابل سوءاستفاده، اطلاعات ورود، داده خصوصی کاربران یا جزئیات حساس را در Issue عمومی منتشر نکنید. از روش تماس خصوصی با مالک مخزن استفاده کنید.

Never commit Android signing keys, keystores, certificates, passwords, API tokens, environment files containing secrets, private data, or production builds.

هرگز کلیدهای امضای اندروید، keystore، گواهی، گذرواژه، توکن API، فایل محیطی حاوی اطلاعات محرمانه، داده خصوصی یا نسخهٔ نهایی تولید را commit نکنید.

If a signing password or credential has ever appeared in a public file or commit history, treat it as exposed. Change the affected password and re-encrypt the same private key where possible. Do not generate a different Android signing key for an already-distributed app unless a supported signing-key migration is planned. Changing a password does not require changing the underlying key pair. Removing a secret from the latest file does not remove it from older commits; history cleanup may be needed, but rotation is still required because copies may remain.

اگر گذرواژه یا اطلاعات ورود امضای برنامه حتی یک‌بار در فایل عمومی یا تاریخچهٔ commit دیده شده است، آن را افشاشده فرض کنید. گذرواژه را عوض کنید و در صورت امکان همان کلید خصوصی را با گذرواژهٔ تازه دوباره رمزگذاری کنید. برای برنامه‌ای که قبلاً منتشر شده، کلید امضای متفاوت نسازید مگر اینکه مسیر رسمی انتقال کلید پشتیبانی شود. تغییر گذرواژه نیازی به تغییر خود جفت‌کلید ندارد. حذف راز از فایل فعلی آن را از commitهای قدیمی پاک نمی‌کند؛ ممکن است پاک‌سازی تاریخچه هم لازم باشد، اما چون نسخه‌هایی از اطلاعات ممکن است باقی مانده باشند، تعویض گذرواژه همچنان ضروری است.

If a secret is exposed, revoke or rotate it immediately and review repository history. Deleting a file in a later commit does not remove it from earlier commits.
