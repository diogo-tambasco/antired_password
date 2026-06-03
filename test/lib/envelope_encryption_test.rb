# frozen_string_literal: true

# Núcleo criptográfico — SPEC.md §4.3. O teste mais importante do projeto.
#
# Escrito para rodar de forma ISOLADA (sem Rails):
#   ruby -Itest test/lib/envelope_encryption_test.rb
# Precisa apenas de: gem `rbnacl` (libsodium) + a classe `EnvelopeEncryption`.

require "minitest/autorun"

begin
  require "rbnacl"
rescue LoadError
  warn "[envelope_encryption_test] gem 'rbnacl' ausente — instale e adicione libsodium ao sistema."
end

# Tenta carregar a implementação real. Enquanto não existir, os testes deste
# arquivo vão dar erro de constante — o "vermelho esperado" (ver test/README.md).
begin
  require "envelope_encryption"
rescue LoadError
  # noop: a referência a EnvelopeEncryption abaixo falhará explicitamente.
end

class EnvelopeEncryptionTest < Minitest::Test
  # senhas de brinquedo — NUNCA usar segredo real em teste
  MASTER = "correct horse battery staple"
  WRONG  = "Tr0ub4dor&3"

  # ---- KDF / KEK (SPEC §4.2, §4.3) -------------------------------------------

  def test_generate_salt_tem_tamanho_de_salt_do_argon2id
    salt = EnvelopeEncryption.generate_salt
    assert_equal RbNaCl::PasswordHash::Argon2::SALTBYTES, salt.bytesize
  end

  def test_dois_salts_sao_diferentes
    refute_equal EnvelopeEncryption.generate_salt, EnvelopeEncryption.generate_salt
  end

  def test_derive_kek_eh_deterministico
    salt = EnvelopeEncryption.generate_salt
    kek1 = EnvelopeEncryption.derive_kek(MASTER, salt)
    kek2 = EnvelopeEncryption.derive_kek(MASTER, salt)
    assert_equal kek1, kek2, "mesma senha + mesmo salt deve gerar a MESMA KEK"
  end

  def test_kek_tem_32_bytes
    salt = EnvelopeEncryption.generate_salt
    assert_equal 32, EnvelopeEncryption.derive_kek(MASTER, salt).bytesize
  end

  def test_salt_diferente_gera_kek_diferente
    kek1 = EnvelopeEncryption.derive_kek(MASTER, EnvelopeEncryption.generate_salt)
    kek2 = EnvelopeEncryption.derive_kek(MASTER, EnvelopeEncryption.generate_salt)
    refute_equal kek1, kek2
  end

  def test_senha_diferente_gera_kek_diferente
    salt = EnvelopeEncryption.generate_salt
    refute_equal EnvelopeEncryption.derive_kek(MASTER, salt),
                 EnvelopeEncryption.derive_kek(WRONG, salt)
  end

  # ---- DEK + wrap/unwrap (SPEC §4, §6.1–6.2) ---------------------------------

  def test_generate_dek_tem_32_bytes_e_eh_aleatoria
    refute_equal EnvelopeEncryption.generate_dek, EnvelopeEncryption.generate_dek
    assert_equal 32, EnvelopeEncryption.generate_dek.bytesize
  end

  def test_wrap_unwrap_round_trip
    kek = EnvelopeEncryption.derive_kek(MASTER, EnvelopeEncryption.generate_salt)
    dek = EnvelopeEncryption.generate_dek
    box = EnvelopeEncryption.wrap_dek(dek, kek)
    recovered = EnvelopeEncryption.unwrap_dek(box[:ciphertext], box[:nonce], kek)
    assert_equal dek, recovered
  end

  def test_wrap_usa_nonce_novo_a_cada_chamada
    kek = EnvelopeEncryption.derive_kek(MASTER, EnvelopeEncryption.generate_salt)
    dek = EnvelopeEncryption.generate_dek
    a = EnvelopeEncryption.wrap_dek(dek, kek)
    b = EnvelopeEncryption.wrap_dek(dek, kek)
    refute_equal a[:nonce], b[:nonce], "nonce deve ser único por cifragem"
    refute_equal a[:ciphertext], b[:ciphertext], "ciphertext deve diferir (nonce novo)"
  end

  def test_unwrap_com_kek_errada_levanta_e_nao_devolve_lixo
    salt = EnvelopeEncryption.generate_salt
    kek_certa  = EnvelopeEncryption.derive_kek(MASTER, salt)
    kek_errada = EnvelopeEncryption.derive_kek(WRONG, salt)
    dek = EnvelopeEncryption.generate_dek
    box = EnvelopeEncryption.wrap_dek(dek, kek_certa)

    # A prova de senha correta é decifrar a DEK (SPEC §3 invariante 2):
    # KEK errada DEVE levantar, nunca devolver nil ou bytes aleatórios.
    assert_raises(RbNaCl::CryptoError) do
      EnvelopeEncryption.unwrap_dek(box[:ciphertext], box[:nonce], kek_errada)
    end
  end

  def test_unwrap_com_ciphertext_adulterado_levanta
    kek = EnvelopeEncryption.derive_kek(MASTER, EnvelopeEncryption.generate_salt)
    box = EnvelopeEncryption.wrap_dek(EnvelopeEncryption.generate_dek, kek)
    tampered = box[:ciphertext].dup
    tampered[0] = (tampered[0].ord ^ 0x01).chr # flip 1 bit
    assert_raises(RbNaCl::CryptoError) do
      EnvelopeEncryption.unwrap_dek(tampered, box[:nonce], kek)
    end
  end

  # ---- AEAD dos valores (SPEC §4.3, §6.4) ------------------------------------

  def test_encrypt_decrypt_round_trip_utf8
    dek = EnvelopeEncryption.generate_dek
    plain = "sk-live-ção-€-🔐-multi-byte"
    enc = EnvelopeEncryption.encrypt(plain, dek)
    assert_equal plain, EnvelopeEncryption.decrypt(enc[:ciphertext], enc[:nonce], dek)
  end

  def test_encrypt_decrypt_round_trip_binario
    dek = EnvelopeEncryption.generate_dek
    plain = RbNaCl::Random.random_bytes(1024)
    enc = EnvelopeEncryption.encrypt(plain, dek)
    assert_equal plain, EnvelopeEncryption.decrypt(enc[:ciphertext], enc[:nonce], dek)
  end

  def test_encrypt_nao_vaza_plaintext_no_ciphertext
    dek = EnvelopeEncryption.generate_dek
    plain = "senha-super-secreta-123"
    enc = EnvelopeEncryption.encrypt(plain, dek)
    refute_includes enc[:ciphertext], plain
  end

  def test_decrypt_com_dek_errada_levanta
    enc = EnvelopeEncryption.encrypt("x", EnvelopeEncryption.generate_dek)
    assert_raises(RbNaCl::CryptoError) do
      EnvelopeEncryption.decrypt(enc[:ciphertext], enc[:nonce], EnvelopeEncryption.generate_dek)
    end
  end

  def test_decrypt_com_nonce_trocado_levanta
    dek = EnvelopeEncryption.generate_dek
    enc = EnvelopeEncryption.encrypt("x", dek)
    outro_nonce = RbNaCl::Random.random_bytes(enc[:nonce].bytesize)
    assert_raises(RbNaCl::CryptoError) do
      EnvelopeEncryption.decrypt(enc[:ciphertext], outro_nonce, dek)
    end
  end
end
