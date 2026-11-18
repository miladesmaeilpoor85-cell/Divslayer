import base64
import io
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from google_omni_video import (  # noqa: E402
    GeminiApiError,
    build_payload,
    extract_video_output,
    load_reference_image,
    parse_file_id,
    _workspace_file,
    _workspace_file_for_output,
)


class GoogleOmniVideoTests(unittest.TestCase):
    def test_build_text_to_video_payload(self):
        payload = build_payload('A cinematic sunrise.', 6, '16:9', '720p')
        self.assertEqual(payload['model'], 'gemini-omni-1.2-flash')
        self.assertEqual(payload['input'], 'A cinematic sunrise.')
        self.assertEqual(payload['response_format']['duration'], '6s')
        self.assertEqual(payload['response_format']['delivery'], 'uri')
        self.assertFalse(payload['store'])

    def test_build_reference_to_video_payload(self):
        encoded = base64.b64encode(b'fake-png-data').decode('ascii')
        payload = build_payload('Animate this reference.', 10, '9:16', '360p', (encoded, 'image/png'))
        self.assertEqual(payload['input'][0]['type'], 'image')
        self.assertEqual(payload['input'][0]['data'], encoded)
        self.assertEqual(payload['input'][1]['text'], 'Animate this reference.')
        self.assertEqual(payload['response_format']['resolution'], '360p')

    def test_payload_rejects_empty_prompt_and_unsupported_resolution(self):
        with self.assertRaises(ValueError):
            build_payload('  ', 6, '16:9', '720p')
        with self.assertRaises(ValueError):
            build_payload('A scene.', 6, '16:9', '4k')

    def test_payload_rejects_invalid_duration_and_aspect_ratio(self):
        with self.assertRaises(ValueError):
            build_payload('A scene.', 2, '16:9', '720p')
        with self.assertRaises(ValueError):
            build_payload('A scene.', 6, '1:1', '720p')

    def test_extract_output_video_uri(self):
        uri, data = extract_video_output({'output_video': {'uri': 'files/video-123'}})
        self.assertEqual(uri, 'files/video-123')
        self.assertIsNone(data)

    def test_extract_output_video_data_from_steps(self):
        uri, data = extract_video_output({
            'steps': [{
                'type': 'model_output',
                'content': [{'type': 'video', 'mime_type': 'video/mp4', 'data': 'AAAA'}],
            }],
        })
        self.assertIsNone(uri)
        self.assertEqual(data, 'AAAA')

    def test_parse_file_id_accepts_google_file_uris(self):
        self.assertEqual(
            parse_file_id('https://generativelanguage.googleapis.com/v1beta/files/abc-123'),
            'abc-123',
        )
        self.assertEqual(parse_file_id('files/abc_123'), 'abc_123')

    def test_parse_file_id_rejects_unknown_host_or_path(self):
        with self.assertRaises(GeminiApiError):
            parse_file_id('https://example.com/attacker/file')
        with self.assertRaises(GeminiApiError):
            parse_file_id('files/../secret')

    def test_sprite_sheet_crop_selects_requested_cell(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = Image.new('RGB', (20, 20))
            image.paste((255, 0, 0), (0, 0, 10, 10))
            image.paste((0, 255, 0), (10, 0, 20, 10))
            image.paste((0, 0, 255), (0, 10, 10, 20))
            image.paste((255, 255, 0), (10, 10, 20, 20))
            image.save(root / 'sheet.png')
            encoded, mime_type = load_reference_image(root, 'sheet.png', '2x2', 2)
            decoded = Image.open(io.BytesIO(base64.b64decode(encoded))).convert('RGB')
            self.assertEqual(mime_type, 'image/png')
            self.assertEqual(decoded.size, (10, 10))
            self.assertEqual(decoded.getpixel((5, 5)), (0, 0, 255))

    def test_reference_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root.parent / 'outside-reference.png'
            outside.write_bytes(b'not-an-image')
            try:
                with self.assertRaises(ValueError):
                    _workspace_file(root, '../outside-reference.png')
            finally:
                outside.unlink(missing_ok=True)

    def test_output_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                _workspace_file_for_output(Path(directory), '../escape.mp4')


if __name__ == '__main__':
    unittest.main()
