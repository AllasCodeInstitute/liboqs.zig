const std = @import("std");

pub const OQS_STATUS = enum(i32) {
    OQS_ERROR = -1,
    OQS_SUCCESS = 0,
};

pub const OQS_RAND_alg_system = "system";
pub const OQS_RAND_alg_openssl = "OpenSSL";

pub const RandomFn = *const fn ([]u8) void;

fn oqs_randombytes_system(random_array: []u8) void {
    std.crypto.random.bytes(random_array);
}

var oqs_randombytes_algorithm: RandomFn = &oqs_randombytes_system;

pub fn OQS_randombytes_switch_algorithm(algorithm: []const u8) OQS_STATUS {
    if (std.ascii.eqlIgnoreCase(OQS_RAND_alg_system, algorithm)) {
        oqs_randombytes_algorithm = &oqs_randombytes_system;
        return .OQS_SUCCESS;
    }

    // Preserva a API C: OpenSSL pode ser escolhido na versão C, mas aqui
    // não há backend OpenSSL; usamos erro explícito.
    if (std.ascii.eqlIgnoreCase(OQS_RAND_alg_openssl, algorithm)) {
        return .OQS_ERROR;
    }

    return .OQS_ERROR;
}

pub fn OQS_randombytes_custom_algorithm(algorithm_ptr: RandomFn) void {
    oqs_randombytes_algorithm = algorithm_ptr;
}

pub fn OQS_randombytes(random_array: []u8) void {
    oqs_randombytes_algorithm(random_array);
}

test "system random fills buffer" {
    var buf: [32]u8 = [_]u8{0} ** 32;
    OQS_randombytes(buf[0..]);

    var all_zero = true;
    for (buf) |b| {
        if (b != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}
