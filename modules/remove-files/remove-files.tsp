import "@typespec/json-schema";
using TypeSpec.JsonSchema;

@jsonSchema("/modules/remove-files.json")
model RemoveFilesModule {
    /** The `remove-files` module can be used to remove the specified files from the image.
    */
    type: "remove-files";

    /** List of files to remove from the image */
    files: Array<string>;
}