"""Sign an APK with APK Signature Scheme v2 (Android 7.0+ / minSdk 24).

usage: python3 apk_sign_v2.py <in.apk> <out.apk> <key_dir>

The key_dir holds key.pem + cert.pem. A new private key is encrypted with a
passphrase. Keep the directory private and backed up: every app update must
use the same signing key. By default the passphrase is requested interactively.
For automation, set DIVSLAYER_SIGNING_KEY_PASSWORD in a protected secret store.
"""
import datetime
import getpass
import hashlib
import os
import struct
import sys

from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding

V2_ID = 0x7109871A
ALG_RSA_PKCS1_SHA256 = 0x0103
MAGIC = b"APK Sig Block 42"
CHUNK = 1 << 20
PASSWORD_ENV = "DIVSLAYER_SIGNING_KEY_PASSWORD"


def _password(confirm: bool = False) -> bytes:
    """Read a signing-key passphrase without echoing it or putting it in argv."""
    value = os.environ.get(PASSWORD_ENV)
    if value is None:
        value = getpass.getpass("Signing key passphrase: ")
        if confirm:
            again = getpass.getpass("Confirm signing key passphrase: ")
            if value != again:
                raise ValueError("Passphrases do not match")
    elif confirm:
        # A protected environment variable is already the confirmed value.
        pass
    if not value:
        raise ValueError("A non-empty signing key passphrase is required")
    if confirm and len(value) < 12:
        raise ValueError("Use a passphrase of at least 12 characters")
    return value.encode("utf-8")


def _write_private_key(path: str, key, password: bytes) -> None:
    payload = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.BestAvailableEncryption(password),
    )
    with open(path, "wb") as f:
        f.write(payload)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def load_or_create_key(key_dir: str):
    os.makedirs(key_dir, mode=0o700, exist_ok=True)
    kp = os.path.join(key_dir, "key.pem")
    cp = os.path.join(key_dir, "cert.pem")
    has_key, has_cert = os.path.isfile(kp), os.path.isfile(cp)

    if has_key != has_cert:
        raise FileNotFoundError(
            "The signing key and certificate must be kept as a matching pair; "
            "restore the missing file from a secure backup."
        )

    if has_key and has_cert:
        raw_key = open(kp, "rb").read()
        supplied = _password()
        try:
            key = serialization.load_pem_private_key(raw_key, password=supplied)
        except TypeError:
            # Upgrade an older unencrypted PEM in place without changing the key.
            key = serialization.load_pem_private_key(raw_key, password=None)
            if os.environ.get(PASSWORD_ENV) is None:
                again = getpass.getpass("Confirm new signing key passphrase: ")
                if supplied.decode("utf-8") != again:
                    raise ValueError("Passphrases do not match")
            if len(supplied) < 12:
                raise ValueError("Use a passphrase of at least 12 characters")
            _write_private_key(kp, key, supplied)
            print(
                "Warning: the existing unencrypted private key was re-saved "
                "with passphrase protection.",
                file=sys.stderr,
            )
        cert = x509.load_pem_x509_certificate(open(cp, "rb").read())
        key_public = key.public_key().public_bytes(
            serialization.Encoding.DER,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        cert_public = cert.public_key().public_bytes(
            serialization.Encoding.DER,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        if key_public != cert_public:
            raise ValueError(
                "The private key does not match the certificate. Restore the matching pair from a secure backup."
            )
        try:
            os.chmod(key_dir, 0o700)
            os.chmod(kp, 0o600)
            os.chmod(cp, 0o600)
        except OSError:
            pass
        return key, cert

    password = _password(confirm=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "Divslayer"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Divslayer"),
    ])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + datetime.timedelta(days=365 * 40))
        .sign(key, hashes.SHA256())
    )
    _write_private_key(kp, key, password)
    with open(cp, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))
    try:
        os.chmod(key_dir, 0o700)
        os.chmod(cp, 0o600)
    except OSError:
        pass
    return key, cert


def lp(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b


def find_eocd(data: bytes) -> int:
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536) - 1, -1):
        if data[i:i + 4] == b"PK\x05\x06":
            comment_len = struct.unpack("<H", data[i + 20:i + 22])[0]
            if i + 22 + comment_len == len(data):
                return i
    raise ValueError("no ZIP end-of-central-directory record")


def chunked_digest(sections) -> bytes:
    digests = []
    for section in sections:
        for offset in range(0, len(section), CHUNK):
            chunk = section[offset:offset + CHUNK]
            digests.append(
                hashlib.sha256(b"\xa5" + struct.pack("<I", len(chunk)) + chunk).digest()
            )
    return hashlib.sha256(
        b"\x5a" + struct.pack("<I", len(digests)) + b"".join(digests)
    ).digest()


def sign(src: str, dst: str, key_dir: str) -> None:
    with open(src, "rb") as f:
        data = f.read()
    eocd = find_eocd(data)
    cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
    if cd_off + cd_size != eocd:
        raise ValueError("unexpected data between central directory and EOCD")
    if data[cd_off - 16:cd_off] == MAGIC:
        raise ValueError("APK is already signed (has an APK Signing Block)")
    s1, s2, s3 = data[:cd_off], data[cd_off:eocd], data[eocd:]
    top = chunked_digest([s1, s2, s3])
    key, cert = load_or_create_key(key_dir)
    cert_der = cert.public_bytes(serialization.Encoding.DER)
    pub_der = key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    digests = lp(lp(struct.pack("<I", ALG_RSA_PKCS1_SHA256) + lp(top)))
    certs = lp(lp(cert_der))
    attrs = lp(b"")
    signed_data = digests + certs + attrs
    sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    signer = (
        lp(signed_data)
        + lp(lp(struct.pack("<I", ALG_RSA_PKCS1_SHA256) + lp(sig)))
        + lp(pub_der)
    )
    value = lp(lp(signer))
    pair = struct.pack("<Q", 4 + len(value)) + struct.pack("<I", V2_ID) + value
    size = len(pair) + 8 + 16
    block = struct.pack("<Q", size) + pair + struct.pack("<Q", size) + MAGIC
    new_eocd = s3[:16] + struct.pack("<I", cd_off + len(block)) + s3[20:]
    with open(dst, "wb") as f:
        f.write(s1 + block + s2 + new_eocd)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: apk_sign_v2.py <in.apk> <out.apk> <key_dir>")
    sign(sys.argv[1], sys.argv[2], sys.argv[3])
    print("signed", sys.argv[2], os.path.getsize(sys.argv[2]))
