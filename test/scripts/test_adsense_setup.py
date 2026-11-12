import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('prepare_adsense', ROOT / 'scripts/prepare_adsense.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AdSenseSetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'web').mkdir()
        (self.root / 'web/index.html').write_text('<head>' + module.START + '\n' + module.END + '</head>')

    def test_real_id_generates_matching_meta_and_ads_txt(self):
        module.prepare_adsense(self.root, {'ADSENSE_PUBLISHER_ID': 'ca-pub-1234567890123456'})
        self.assertIn('name="google-adsense-account" content="ca-pub-1234567890123456"',
                      (self.root / 'web/index.html').read_text())
        self.assertIn('google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0',
                      (self.root / 'web/ads.txt').read_text())

    def test_removal_is_idempotent_and_never_leaves_fake_seller(self):
        module.prepare_adsense(self.root, {'ADSENSE_PUBLISHER_ID': 'ca-pub-1234567890123456'})
        module.prepare_adsense(self.root, {})
        module.prepare_adsense(self.root, {})
        self.assertNotIn('google-adsense-account', (self.root / 'web/index.html').read_text())
        self.assertNotIn('DIRECT', (self.root / 'web/ads.txt').read_text())

    def test_invalid_publisher_rejected_before_any_write(self):
        for value in ['fake', 'ca-pub-1', '<script>alert(1)</script>']:
            with self.assertRaises(ValueError):
                module.prepare_adsense(self.root, {'ADSENSE_PUBLISHER_ID': value})
        self.assertFalse((self.root / 'web/ads.txt').exists())


if __name__ == '__main__': unittest.main()
