// TODO: Not sure how to get this working with passing as STDIN to `| node -`

// Cannot set to CommonJS modules when executing with `node -`
const Fs = require('fs').promises;
const FsSync = require('fs');
//import { promises as Fs } from 'fs';
//import * as FsSync from 'fs';

//run: node % subtitles /dev/stdout

// Need this because we are of passing to node via STDIN
(async () => {
  const sub_dir = process.argv[2];
  const out_path = process.argv[3];

  const file_list = await Fs.readdir(sub_dir);
  //try {
  //  await Fs.mkdir(out);
  //} catch (err) {
  //  if (err.code != 'EEXIST') {
  //    console.log(err);
  //    process.exit(1);
  //  }
  //}

  const length = file_list.length;
  const result = new Array(length);
  let webttv_length = 0;
  for (let i = 0; i < length; ++i) {
    const filename = file_list[i];
    if (filename.endsWith(".vtt")) {
      // Sync version
      const contents = FsSync.readFileSync(`${sub_dir}/${filename}`, 'utf8');
      const text = parse_webvtt(contents);
      result[webttv_length] = {
          id: filename.substring(0, 11), // youtube ids are 11 characters
          text,
      };

      // TODO: Figure out why the Async version is crashing

      // Async verison

      //console.error(`${sub_dir}/${filename}`);
      //result[webttv_length] = Fs.readFile(`${sub_dir}/${filename}`, "UTF8")
      //  .then(parse_webvtt)
      //  .then(text => ({
      //    id: filename.substring(0, 11), // youtube ids are 11 characters
      //    text,
      //  })).await;

      ++webttv_length;
    } else {
      console.error(`Error ${filename}`);
    }
  }

  // Sync
  Fs.writeFile(out_path, JSON.stringify(result), "UTF8");

  // Async
  //const output = await Promise.all(result);
  //Fs.writeFile(out_path, JSON.stringify(output), "UTF8");
})();


function parse_webvtt(input_string) {
  if (typeof input_string !== "string") {
    throw new ParseError("Not a string");
  }
  // Guard against Windows "/r/n" (probably not necessary)
  input_string = input_string.replace(/\r\n|\r/, "\n");
  // Delimiter is a blank line
  const input = input_string.split('\n\n');

  if (!input[0].startsWith("WEBVTT") && !input[0].substring(1).startsWith("WEBVTT")) {
    throw new ParseError("Invalid vtt format: Does not start with 'WEBVTT' or '[BOM]WEBVTT'. [BOM] is a single byte");
  }

  const cues = parse_cues(input, 1);
  return "<p>" + cues.filter(x => x != ' ' && x != '').join("</p>\n</p>") + "</p>";
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


