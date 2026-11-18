"""Sign an APK with APK Signature Scheme v2 (enough for Android 7.0+ / minSdk 24).
usage: python3 apk_sign_v2.py <in.apk> <out.apk> <key_dir>
key_dir holds key.pem + cert.pem; they are created on first use. Keep them: every update
of the app must be signed with the same key."""
import hashlib, os, struct, sys, datetime
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding

V2_ID = 0x7109871A
ALG_RSA_PKCS1_SHA256 = 0x0103
MAGIC = b"APK Sig Block 42"
CHUNK = 1 << 20

def lp(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b

def load_or_create_key(key_dir: str):
    kp, cp = os.path.join(key_dir, "key.pem"), os.path.join(key_dir, "cert.pem")
    if os.path.exists(kp) and os.path.exists(cp):
        key = serialization.load_pem_private_key(open(kp, "rb").read(), password=None)
        cert = x509.load_pem_x509_certificate(open(cp, "rb").read())
        return key, cert
    os.makedirs(key_dir, exist_ok=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Ember and Iron"), x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Ember and Iron")])
    now = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now)
            .not_valid_after(now + datetime.timedelta(days=365 * 40)).sign(key, hashes.SHA256()))
    open(kp, "wb").write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    open(cp, "wb").write(cert.public_bytes(serialization.Encoding.PEM))
    return key, cert

def find_eocd(data: bytes) -> int:
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536) - 1, -1):
        if data[i:i + 4] == b"PK\x05\x06":
            comment_len = struct.unpack("<H", data[i + 20:i + 22])[0]
            if i + 22 + comment_len == len(data):
                return i
    raise ValueError("no ZIP end-of-central-directory record")

def chunked_digest(sections) -> bytes:
    digests = []
    for s in sections:
        for o in range(0, len(s), CHUNK):
            c = s[o:o + CHUNK]
            digests.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(c)) + c).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(digests)) + b"".join(digests)).digest()

def sign(src: str, dst: str, key_dir: str) -> None:
    data = open(src, "rb").read()
    eocd = find_eocd(data)
    cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
    assert cd_off + cd_size == eocd, "unexpected data between central directory and EOCD"
    if data[cd_off - 16:cd_off] == MAGIC:
        raise ValueError("APK is already signed (has an APK Signing Block)")
    s1, s2, s3 = data[:cd_off], data[cd_off:eocd], data[eocd:]
    top = chunked_digest([s1, s2, s3])
    key, cert = load_or_create_key(key_dir)
    cert_der = cert.public_bytes(serialization.Encoding.DER)
    pub_der = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    digests = lp(lp(struct.pack("<I", ALG_RSA_PKCS1_SHA256) + lp(top)))
    certs = lp(lp(cert_der))
    attrs = lp(b"")
    signed_data = digests + certs + attrs
    sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    signer = lp(signed_data) + lp(lp(struct.pack("<I", ALG_RSA_PKCS1_SHA256) + lp(sig))) + lp(pub_der)
    value = lp(lp(signer))
    pair = struct.pack("<Q", 4 + len(value)) + struct.pack("<I", V2_ID) + value
    size = len(pair) + 8 + 16
    block = struct.pack("<Q", size) + pair + struct.pack("<Q", size) + MAGIC
    new_eocd = s3[:16] + struct.pack("<I", cd_off + len(block)) + s3[20:]
    open(dst, "wb").write(s1 + block + s2 + new_eocd)

if __name__ == "__main__":
    sign(sys.argv[1], sys.argv[2], sys.argv[3])
    print("signed", sys.argv[2], os.path.getsize(sys.argv[2]))
