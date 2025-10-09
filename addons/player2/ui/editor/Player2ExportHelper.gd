class_name Player2ExportHelper

static func _save_folder_conents_as_zip_and_consume(zip_path : String, path : String) -> int:
	var writer = ZIPPacker.new()
	var err = writer.open(zip_path)
	if err != OK:
		return err

	for fname in DirAccess.get_files_at(path):
		var fpath := path + "/" + fname
		#print("guh ", fpath)
		writer.start_file(fname)
		writer.write_file(FileAccess.get_file_as_bytes(fpath))
		writer.close_file()
		DirAccess.remove_absolute(fpath)

	writer.close()

	return OK

static func export_web_zip() -> String:
	var path = "Builds"
	if !DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)

	var build_folder : String = path + "/Web"
	if DirAccess.dir_exists_absolute(build_folder):
		var i = 1
		while DirAccess.dir_exists_absolute(build_folder + "_" + str(i)):
			i += 1
		DirAccess.rename_absolute(build_folder, build_folder + "_" + str(i))

	DirAccess.make_dir_absolute(build_folder)

	var build_path : String = build_folder + "/index.html" # "C:/Users/adris/Documents/player2-ai-npc-godot/Builds/index.html"

	var export_platform : EditorExportPlatformWeb = EditorExportPlatformWeb.new()
	var preset := export_platform.create_preset()
	var err := export_platform.export_project(preset, true, build_path)
	
	var export_path = path + "/WebExport.zip"
	_save_folder_conents_as_zip_and_consume(export_path, build_folder)

	DirAccess.remove_absolute(build_folder)

	print(err)
	
	return export_path
