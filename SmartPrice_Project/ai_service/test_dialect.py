"""Test dialect normalization pipeline."""
import importlib.util, sys
spec = importlib.util.spec_from_file_location('main', 'main.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

print('=== SmartPrice Dialect Test ===')
print(f'Extended dialect entries: {len(m._EXTENDED_DIALECT_MAP)}')
print(f'Hardcoded entries:        {len(m.DIALECT_WORD_MAP)}')
print(f'Number patterns:          {len(m.DIALECT_NUMBER_MAP)}')
print()

tests = [
    ('Sáng nay uống cà phê hết hăm lăm ngàn', 25000, 'Ăn uống'),
    ('Mần cái bánh mỳ mười lăm ngàn',          15000, 'Ăn uống'),
    ('Đi xe ôm hết hai chục',                   20000, 'Di chuyển'),
    ('Tui xài hết năm chục ngàn mua đồ',        50000, 'Mua sắm'),
    ('Nỏ thích nhưng vẫn mần tô phở hết ba chục', 30000, 'Ăn uống'),
    ('Hôm nay ăn phở hết 50k',                  50000, 'Ăn uống'),
    ('Grab về nhà 35 nghìn',                     35000, 'Di chuyển'),
]

passed = 0
for text, expected_amount, expected_cat in tests:
    normalized = m.normalize_dialect(text)
    amount     = m.extract_amount_vi(text)
    category   = m.detect_category(text + ' ' + normalized)
    ok_amount  = abs(amount - expected_amount) < 1000
    ok_cat     = category == expected_cat
    ok         = ok_amount and ok_cat
    if ok: passed += 1
    status = 'PASS' if ok else 'FAIL'
    print(f'[{status}] "{text}"')
    print(f'       normalized: "{normalized}"')
    print(f'       amount: {amount} (exp {expected_amount}) {"OK" if ok_amount else "WRONG"}')
    print(f'       category: {category} (exp {expected_cat}) {"OK" if ok_cat else "WRONG"}')
    print()

print(f'Result: {passed}/{len(tests)} passed')
