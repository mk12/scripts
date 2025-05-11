from itertools import permutations

def show(heading):
    print(f"\n# {heading}\n")

def table(k, f, mapping=None):
    n = 2 ** k
    if not mapping:
        mapping = {i: i for i in range(n)}
    rev = {mapping[i]: i for i in range(n)}
    def fmt(x):
        s = bin(x)[2:].zfill(k)
        c = [90, 1, 31, 32, 33, 34, 35, 36][rev[x]]
        return f"\x1b[{c}m{s}\x1b[0m"
    print(" " * (k + 3), end="")
    for b in range(n):
        print(fmt(mapping[b]), end=" ")
    print()
    print(" " * (k + 3), end="")
    print("--- " * n)
    for a in range(n):
        print(fmt(mapping[a]), end=" | ")
        for b in range(n):
            print(fmt(f(mapping[a], mapping[b])), end=" ")
        print()

# Multiplies in Z2[x]/p(x)
def multmod(p):
    k = p.bit_length() - 1
    assert p & (1 << k)
    assert p >> (k + 1) == 0
    m = (k - 1) * 2
    test = lambda x: 0 if x == 0 else 1
    def helper(a, b):
        poly = lambda x: {i: test(x & (1 << i)) for i in range(k)}
        r = {i: 0 for i in range(m + 1)}
        for ia, va in poly(a).items():
            for ib, vb in poly(b).items():
                i = ia + ib
                r[i] = (r[i] + va * vb) % 2
        assert max(r.keys()) <= 4
        assert all(v in [0, 1] for v in r.values())
        if r[4] == 1:
            for i in range(k + 1):
                x = test(p & (1 << i))
                r[i+1] = (r[i+1] + x) % 2
        if r[3] == 1:
            for i in range(k + 1):
                x = test(p & (1 << i))
                r[i] = (r[i] + x) % 2
        ret = sum(v << i for i, v in r.items())
        assert ret < 2 ** k
        return ret
    return helper

def find_isomorphism(k, src_ops, dst_ops):
    xs = list(range(2 ** k))
    def check(p):
        for i in xs:
            for j in xs:
                for (src, dst) in zip(src_ops, dst_ops):
                    if p[src(i, j)] != dst(p[i], p[j]):
                        return False
        return True
    for p in permutations(xs):
        if check(p):
            return p
    assert False, "no isomorphism found"


# Addition: XOR (equivalently, addition in Z2[x]/p(x))
def add(a, b):
    return a ^ b

# Multiplication: in Z2[x]/p(x) where p(x) = x^3 + x + 1
mult1 = multmod(0b1011)

# Multiplication: in Z2[x]/p(x) where p(x) = x^3 + x^2 + 1
mult2 = multmod(0b1101)

show("Addition")
table(3, add)

show("Multiplication mod x^3 + x + 1")
table(3, mult1)

# show("Multiplication mod x^3 + x^2 + 1")
# table(3, mult2)

# dst: src
iso = find_isomorphism(3, [add, mult2], [add, mult1])
print(iso)

show("Multiplication mod x^3 + x^2 + 1, mapped by isomorphism")
table(3, mult2, iso)

show("Addition, mapped by isomorphism")
table(3, add, iso)

# for i in range(8):
#     for j in range(8):
#         m1 = mult1(i, j)
#         m2 = mult2(i, j)
#         print(f"{i:b} * {j:b} --- {mult1(i, j):b} --- {mult2(i)}")
