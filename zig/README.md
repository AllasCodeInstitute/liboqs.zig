# Zig port (in progress)

Este diretório contém uma conversão inicial de partes da lib de C para Zig,
mantendo os mesmos nomes públicos de funções e estrutura de uso onde possível.

## Arquivo inicial

- `zig/src/rand.zig`: porta da lógica de `src/common/rand/rand.c` para Zig,
  usando `std.crypto.random` (evita branches por SO e chamadas C específicas,
  simplificando e otimizando a geração de bytes aleatórios em Zig).

- `zig/src/rand_nist.zig`: porta da DRBG NIST (CTR-DRBG AES-256) com as mesmas funções públicas do C, mantendo estado explícito e usando AES de `std.crypto`.

- `zig/stress/algo.zig`: teste de stress configurável que gera `algo.json` com métricas por estágio (tempo/operações).
