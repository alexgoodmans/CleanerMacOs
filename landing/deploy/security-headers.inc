# Shared security headers for againcleaner.com.
#
# nginx quirk: any `add_header` inside a location drops ALL headers inherited
# from the server level. So every location that sets its own header (e.g.
# Cache-Control) must re-include this file, or the security headers vanish
# for exactly those responses.
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options DENY always;
add_header Referrer-Policy strict-origin-when-cross-origin always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; img-src 'self' data: https://mc.yandex.ru; style-src 'self' 'unsafe-inline'; script-src 'self' https://mc.yandex.ru; connect-src 'self' https://mc.yandex.ru https://mc.yandex.com; worker-src 'self' blob:; child-src 'self' blob: https://mc.yandex.ru; font-src 'self' data:" always;
