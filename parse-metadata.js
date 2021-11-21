// TODO: Not sure how to get this working with passing as STDIN to `| node -`
//import { promises as Fs } from 'fs';
const Fs = require('fs').promises;
//run: time node % ../ablc-data/metadata ../ablc-data/subtitle /dev/stdout

// Need this because we are of passing to node via STDIN
(async () => {
  const info_dir = process.argv[2];
  const subs_dir = process.argv[3];
  const target_path = process.argv[4];

  const json_info_list = await Fs.readdir(info_dir);

  const length = json_info_list.length;
  const result = new Array(length);
  for (let i = 0; i < length; ++i) {
    const filename = json_info_list[i];
    const json_str = await Fs.readFile(`${info_dir}/${filename}`, "UTF8");
    const { id, uploader_id, webpage_url, upload_date,
      title, description, thumbnail, thumbnails
    } = JSON.parse(json_str);

    // Default to [entry].thumbnail, but prefers [entry].thumbnails 336 width
    let tn = thumbnail;
    const thumbnail_count = thumbnails.length;
    for (let j = 1; j < thumbnail_count; ++j) {
      const { url, width } = thumbnails[j];
      if (width == 336) {
        tn = url;
      }
    }

    let transcript = "";
    try {
      const text = await Fs.readFile(`${subs_dir}/${id}.en.vtt`, "UTF8");
      transcript =  parse_webvtt(text);
    } catch(e) {
      console.error(`Could not find subtitles for ${id}. ${e}`)
    }

    result[i] = {
      id,
      uploader_id,
      upload_date: upload_date,
      url: webpage_url,
      title,
      description,
      thumbnail: tn,
      transcript,
    };
  }

  const info_list = await Promise.all(result);
  const trimmed_info_list = info_list
    .filter(entry => entry.uploader_id == "HeiJinZhengZhi")
    .map(entry => { delete entry.uploader_id; return entry; })
    .sort((a, b) => a.upload_date > b.upload_date ? -1 : 1);
  Fs.writeFile(target_path, JSON.stringify(trimmed_info_list), "UTF8");
})();



// Parser functions
function parse_webvtt(input_string) {
  if (typeof input_string !== "string") {
    throw new Error("Not a string");
  }
  // Guard against Windows "/r/n" (probably not necessary)
  input_string = input_string.replace(/\r\n|\r/, "\n");
  // Delimiter is a blank line
  const input = input_string.split('\n\n');

  if (!input[0].startsWith("WEBVTT") && !input[0].substring(1).startsWith("WEBVTT")) {
    throw new Error("Invalid vtt format: Does not start with 'WEBVTT' or '[BOM]WEBVTT'. [BOM] is a single byte");
  }

  const cues = parse_cues(input, 1);
  return cues.filter(x => x != ' ' && x != '').join("\n");
}

function parse_cues(input, start) {
  const length = input.length;
  //const output = new Array(Math.ceil(length / 2));
  const output = new Array(length - 1);
  let index = 0;
  let cache = " ";
  for (; start < length; ++start) {
    const cue = input[start].split("\n");
    if (cache != cue[2] && typeof cue[2] === "string") {
      cache = cue[2]; // Remove duplicate lines
      // Subs often show the same line twice as the following:
      //
      // -------------------------------------------
      //
      //     This is line one where I start speaking
      // -------------------------------------------
      //     This is line one where I start spekaing
      //     This is line two
      // -------------------------------------------
      //
      // This is displayed in a scrolling fashion where the same line moves
      // one line up. We want to delete these repeats

      // Remove all <c> and </c>
      output[index] = cue[2].replace(/<[^>]*>/g, "");
      index += 1;
    }
  }
  //if (length > 0) {
  //  const cue = input[length - 1].split("\n");
  //  console.log(cue);
  //  //output[index] = cue[2].replace(/<.*>/g, "");
  //}
  return output.slice(0, index);
}



