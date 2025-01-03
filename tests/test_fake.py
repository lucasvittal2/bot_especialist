import unittest


class TestGenericSuccess(unittest.TestCase):
    def test_always_success(self):
        """This test will always succeed."""
        self.assertTrue(True)


if __name__ == "__main__":
    unittest.main()
