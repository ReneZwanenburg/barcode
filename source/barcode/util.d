module barcode.util;

import std.exception;
import std.typecons : Flag;
import std.bitmanip : bitfields;

public import std.typecons : tuple;
public import std.bitmanip : BitArray;

alias AppendCheckSum = Flag!"appendCheckSum";

struct Bits(T=ulong)
    if (is(T==ubyte) || is(T==ushort) || is(T==uint) || is(T==ulong))
{
         static if (is(T==ubyte))  enum COUNTBITS = 3;
    else static if (is(T==ushort)) enum COUNTBITS = 4;
    else static if (is(T==uint))   enum COUNTBITS = 5;
    else static if (is(T==ulong))  enum COUNTBITS = 6;

    enum VALUEBITS = T.sizeof * 8 - COUNTBITS;

    mixin(bitfields!(ubyte, "count", COUNTBITS,
                         T, "value", VALUEBITS));

    alias value this;


    pure nothrow @nogc
    this(ulong cnt, ulong val)
    {
        count = cast(ubyte)cnt;
        value = cast(T)val;
    }
}

void addBits(ref BitArray ba, size_t value, int bits)
{
    enforce(bits <= size_t.sizeof*8, "so many bits");
    enforce(bits >= 0, "bits must be more that 0");
    foreach_reverse (i; 0 .. bits)
        ba ~= cast(bool)((value>>i)&1);
}

unittest
{
    BitArray ba;
    ba.addBits(0b11000111010, 11);
    auto tst = BitArray([1,1,0,0,0,1,1,1,0,1,0]);
    assert (ba == tst);
}

void addBits(T)(ref BitArray ba, auto ref const(Bits!T) bits)
{ ba.addBits(bits.value, bits.count); }

unittest
{
    BitArray ba;
    ba.addBits(bits!"##---###-#-");
    auto tst = BitArray([1,1,0,0,0,1,1,1,0,1,0]);
    assert (ba == tst);
}

template bits(string mask, char ONE='#')
    if (mask.length <= 58)
{
    static pure auto bitsImpl(T)() nothrow @nogc
    {
        ulong ret;
        foreach (i; 0 .. mask.length)
            ret |= cast(ulong)(mask[i] == ONE) << (mask.length - 1 - i);
        return Bits!T(mask.length, ret);
    }

         static if (mask.length < 6)  alias S = ubyte;
    else static if (mask.length < 13) alias S = ushort;
    else static if (mask.length < 28) alias S = uint;
    else                              alias S = ulong;

    static if (mask.length >= 1) enum bits = bitsImpl!S();
    else static assert(0, "can't create 0 bits value");
}

unittest
{
    assert(1 == bits!"#");
    assert(0 == bits!"-");
    assert(0b1100011101011 == bits!"##---###-#-##");
    assert(bits!"---".count == 3);
}

auto getDict(alias F, T)(T[] arr)
{
    alias frt = typeof(F(size_t(0), T.init));
    alias KEY = typeof(frt.init[0]);
    alias VAL = typeof(frt.init[1]);

    VAL[KEY] ret;
    foreach (i, e; arr)
    {
        auto tmp = F(i, e);
        ret[tmp[0]] = tmp[1];
    }
    return ret;
}

unittest
{
    static struct X { char ch; ushort mask; }
    enum data = [ X('0', 0b001), X('1', 0b010), X('2', 0b100), ];

    {
        enum ushort[char] t = getDict!((i,a) => tuple(a.ch, a.mask))(data);
        static assert(t.keys.length == 3);
        assert('0' in t);
        assert(t['0'] == 0b001);
        assert('1' in t);
        assert(t['1'] == 0b010);
        assert('2' in t);
        assert(t['2'] == 0b100);
    }

    {
        enum ushort[char] t = getDict!((i,a) => tuple(a.ch, i))(data);
        static assert(t.keys.length == 3);
        assert('0' in t);
        assert(t['0'] == 0);
        assert('1' in t);
        assert(t['1'] == 1);
        assert('2' in t);
        assert(t['2'] == 2);
    }

    {
        enum char[ubyte] t = getDict!((i,a) => tuple(cast(ubyte)i, a.ch))(data);
        static assert(t.keys.length == 3);
        assert(0 in t);
        assert(t[0] == '0');
        assert(1 in t);
        assert(t[1] == '1');
        assert(2 in t);
        assert(t[2] == '2');
    }
}
