import  *  as Headers from './headers.mjs';
import { MAX_LEN } from '../build.mjs';

//run: ../../make.sh eisel -l

export default function full_index(config, rel_path, title, video_list) {
  return `<!DOCTYPE html>
<html>
<head>${
  Headers.head(title)}
  <style>
    main li {
      /* else there is not enough space for four digits */
      /* top right bottom left */
      margin: 0em 2em 2em 2em;
    }
    .description {
      height: 10em;
      overflow-y: auto;
    }
    .list-item {
      display: grid;
      grid-template-columns: 4em auto;
      padding: 20px 0px 20px 0px;
    }
    .list-item h2, p2 {
      padding: 0px 30px 0px 0px;
    }
    .number {
      margin: auto;
    }
  </style>
</head>
<body>${
  Headers.navbar(config, rel_path)}
  <main class="thin-column">
    <aside></aside>
    <section>
      <ol>${
function () {
  var i = 0;
  return video_list.map(({ id, url, title, upload_date, description}) => {
    // Need 'v-' because github-pages privates files prefixed by underscore
    return `
<li class="coloured-item list-item">
  <div class="number">${++i}</div>
  <div>
    <h2><a href="${config.domain}/video/v-${id}.html">${title}</a></h2>
    <p>${Headers.format_date(upload_date)} <a href="${url}">[YT link]</a></p>
    <p class="description">${
      Headers.format_desc(description)
      //Headers.format_desc(Headers.ellipt(description, MAX_LEN))
}</p>
  </div>
</li>`;
  }).join("");
}()}
      </ol>
    </section>
    <aside></aside>
  </main>
  ${Headers.footer()}
</body>
</html>`;
}
        //<p>${}</p>
