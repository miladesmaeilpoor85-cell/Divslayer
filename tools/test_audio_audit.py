import unittest

from audio_audit import parse_probe_payload


class AudioAuditTests(unittest.TestCase):
    def test_extracts_audio_stream_metadata(self):
        payload = {
            "format": {"duration": "12.5", "bit_rate": "192000"},
            "streams": [{
                "codec_type": "audio",
                "codec_name": "vorbis",
                "sample_rate": "44100",
                "channels": 2,
            }],
        }
        self.assertEqual(
            parse_probe_payload(payload),
            {
                "codec": "vorbis",
                "sample_rate_hz": 44100,
                "channels": 2,
                "duration_seconds": 12.5,
                "bit_rate": "192000",
            },
        )

    def test_rejects_video_only_file(self):
        with self.assertRaisesRegex(ValueError, "no audio stream"):
            parse_probe_payload({"format": {"duration": "1"}, "streams": [{"codec_type": "video"}]})

    def test_rejects_missing_or_zero_duration(self):
        with self.assertRaisesRegex(ValueError, "duration"):
            parse_probe_payload({"format": {}, "streams": [{"codec_type": "audio", "sample_rate": "44100", "channels": 2}]})
        with self.assertRaisesRegex(ValueError, "positive"):
            parse_probe_payload({"format": {"duration": "0"}, "streams": [{"codec_type": "audio", "sample_rate": "44100", "channels": 2}]})

    def test_rejects_invalid_audio_stream_metadata(self):
        with self.assertRaisesRegex(ValueError, "sample rate"):
            parse_probe_payload({"format": {"duration": "3"}, "streams": [{"codec_type": "audio", "sample_rate": "0", "channels": 2}]})


if __name__ == "__main__":
    unittest.main()
