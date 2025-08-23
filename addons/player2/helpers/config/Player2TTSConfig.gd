@tool
class_name Player2TTSConfig
extends Resource

enum Gender {MALE, FEMALE, OTHER}
enum Language { en_US, en_GB, ja_JP, zh_CN, es_ES, fr_FR, hi_IN, it_IT, pt_BR }

## Speed Scale (1 is default)
@export var tts_speed : float = 1
## Default TTS language (overriden if `Player 2 Selected Character` is enabled)
@export var tts_default_language : Language = Language.en_US
## Default TTS gender (overriden if `Player 2 Selected Character` is enabled)
# switching to male because for some reason female US doesn't work?
@export var tts_default_gender : Gender = Gender.MALE
