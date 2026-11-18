import unittest
from types import SimpleNamespace

from audio_audit import stream_metadata


class AudioAuditTests(unittest.TestCase):
    def make_stream(self, codec="vorbis", sample_rate=44100, channels=2):
        layout = SimpleNamespace(nb_channels=channels)
        context = SimpleNamespace(name=codec, sample_rate=sample_rate, layout=layout)
        return SimpleNamespace(codec_context=context)

    def test_extracts_audio_stream_metadata(self):
        self.assertEqual(
            stream_metadata(self.make_stream(), 12.5),
            {
                "codec": "vorbis",
                "sample_rate_hz": 44100,
                "channels": 2,
                "duration_seconds": 12.5,
            },
        )

    def test_rejects_non_positive_duration(self):
        with self.assertRaisesRegex(ValueError, "duration"):
            stream_metadata(self.make_stream(), 0)

    def test_rejects_invalid_sample_rate(self):
        with self.assertRaisesRegex(ValueError, "sample rate"):
            stream_metadata(self.make_stream(sample_rate=0), 3)

    def test_rejects_invalid_channel_count(self):
        with self.assertRaisesRegex(ValueError, "channel count"):
            stream_metadata(self.make_stream(channels=0), 3)


if __name__ == "__main__":
    unittest.main()
