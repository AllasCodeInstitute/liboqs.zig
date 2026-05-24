const std = @import("std");
const aes = std.crypto.core.aes;

pub const OQS_NIST_DRBG_struct = extern struct {
    Key: [32]u8,
    V: [16]u8,
    reseed_counter: i32,
};

var DRBG_ctx: OQS_NIST_DRBG_struct = .{
    .Key = [_]u8{0} ** 32,
    .V = [_]u8{0} ** 16,
    .reseed_counter = 0,
};

inline fn incrementV(V: *[16]u8) void {
    var j: usize = 16;
    while (j > 0) {
        j -= 1;
        if (V[j] == 0xff) {
            V[j] = 0x00;
            continue;
        }
        V[j] +%= 1;
        break;
    }
}

inline fn AES256_ECB(key: *const [32]u8, ctr: *const [16]u8, buffer: *[16]u8) void {
    const ctx = aes.Aes256.initEnc(key.*);
    ctx.encrypt(buffer, ctr);
}

fn AES256_CTR_DRBG_Update(provided_data: ?*const [48]u8, Key: *[32]u8, V: *[16]u8) void {
    var temp: [48]u8 = undefined;

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        incrementV(V);

        var block: [16]u8 = undefined;
        AES256_ECB(Key, V, &block);
        @memcpy(temp[i * 16 .. i * 16 + 16], block[0..16]);
    }

    if (provided_data) |pd| {
        for (temp, 0..) |*b, idx| {
            b.* ^= pd[idx];
        }
    }

    @memcpy(Key[0..32], temp[0..32]);
    @memcpy(V[0..16], temp[32..48]);
}

pub fn OQS_randombytes_nist_kat_init_256bit(entropy_input: *const [48]u8, personalization_string: ?*const [48]u8) void {
    var seed_material: [48]u8 = entropy_input.*;

    if (personalization_string) |ps| {
        for (seed_material, 0..) |*b, idx| {
            b.* ^= ps[idx];
        }
    }

    @memset(DRBG_ctx.Key[0..], 0);
    @memset(DRBG_ctx.V[0..], 0);
    AES256_CTR_DRBG_Update(&seed_material, &DRBG_ctx.Key, &DRBG_ctx.V);
    DRBG_ctx.reseed_counter = 1;
}

pub fn OQS_randombytes_nist_kat(x: []u8) void {
    var offset: usize = 0;

    while (offset < x.len) {
        incrementV(&DRBG_ctx.V);

        var block: [16]u8 = undefined;
        AES256_ECB(&DRBG_ctx.Key, &DRBG_ctx.V, &block);

        const remaining = x.len - offset;
        const n = @min(@as(usize, 16), remaining);
        @memcpy(x[offset .. offset + n], block[0..n]);
        offset += n;
    }

    AES256_CTR_DRBG_Update(null, &DRBG_ctx.Key, &DRBG_ctx.V);
    DRBG_ctx.reseed_counter += 1;
}

pub fn OQS_randombytes_nist_kat_get_state(out: *OQS_NIST_DRBG_struct) void {
    out.* = DRBG_ctx;
}

pub fn OQS_randombytes_nist_kat_set_state(in_state: *const OQS_NIST_DRBG_struct) void {
    DRBG_ctx = in_state.*;
}

test "nist kat deterministic with saved state" {
    const entropy = [_]u8{0x42} ** 48;
    OQS_randombytes_nist_kat_init_256bit(&entropy, null);

    var s: OQS_NIST_DRBG_struct = undefined;
    OQS_randombytes_nist_kat_get_state(&s);

    var a: [64]u8 = undefined;
    OQS_randombytes_nist_kat(a[0..]);

    OQS_randombytes_nist_kat_set_state(&s);
    var b: [64]u8 = undefined;
    OQS_randombytes_nist_kat(b[0..]);

    try std.testing.expectEqualSlices(u8, a[0..], b[0..]);
}
