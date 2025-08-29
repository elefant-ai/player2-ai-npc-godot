## Security by obscurity layer (since players can access the key anyway, just a tiny extra layer for encryption)
class_name Player2CrappyEncryption

## Don't roll your own crypto kids
static func encrypt_unsecure(text : String, salt : String = "asdf") -> String:
	var modifier = abs(hash(salt)) if salt and !salt.is_empty() else 0

	var b : PackedByteArray = text.to_utf8_buffer()
	var r : PackedByteArray = PackedByteArray(b)
	for i in range(r.size()):
		var prev = r[i]
		r[i] = (r[i] + modifier) % 256
	return r.hex_encode()

## Don't roll your own crypto kids
static func decrypt_unsecure(text : String, salt : String = "asdf") -> String:
	var modifier = abs(hash(salt)) if salt and !salt.is_empty() else 0

	var b : PackedByteArray = text.hex_decode()
	var r : PackedByteArray = PackedByteArray(b)
	for i in range(r.size()):
		var prev = r[i]
		r[i] = (r[i] + 256 - modifier) % 256
	return r.get_string_from_utf8()
