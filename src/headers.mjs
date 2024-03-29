//run: ../../make.sh eisel -l -f

export function head(title) {
  return `
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="ie=edge">
  <title>${title}</title>
  <style>
    /* Overall structure */
    body { margin: 0px; padding: 0px; border: 0px; }
    span, div, p, h1, h2, h3, h4, h5, h6 { line-height: 1.3em; }
    @media screen and (min-width: 1200px) {
      .medium-column {
        display: grid;
        /* 768 (thin) + 336px (thumnail) */
        grid-template-columns: minmax(0, 1fr) 1104px minmax(0, 1fr);
      }
    }
    @media screen and (min-width: 768px) {
      .thin-column {
        display: grid;
        grid-template-columns: minmax(0, 1fr) 768px minmax(0, 1fr);
      }
    }


    /* Palette
      #FAF9FA
      #8695A8
      #E39940
      #A05148
      #2B2F3A
    */
    /* Colour */
    body           { background: #DAD9DA; }
    .coloured-item { background: #FDFDFA; }
    nav, footer    { background: #C5F6DF; }
    /* nav            { color: #FAF9FA; } */

    /* Overall structure */
    /* top right bottom left */
    main {  padding: 40px 20px 20px 20px; }
    nav {
      position: fixed;
      top: 0px;
      /* border-bottom: solid 1px black; */
      height: 40px;
      width: 100%;
    }
    nav span {
      display: inline-block;
      padding: 10px 15px;
      text-align: center;
      vertical-align: center;
    }
    nav .search {
      float: right;
    }
    footer {
      /* border-top: solid 1px black; */
      padding-top: 8px;
      text-align: center;
    }

    h1, h2, h3, h4, h5, h6 {
      font-family: Verdana, Helvetica, "Dejavu Sans", "Noto Sans", sans-serif;
    }
    p {
      font-faily: Calibri, "Times New Roman", "Open Sans", serif;
    }
  </style>`
};


export function navbar(config, rel_path) {
  // Spans might not be good for ARIA
  return `
  <nav><!--
    --><span>${format_nav_link("Home",      rel_path, `${config.domain}/`)}</span><!--
    --><span>${format_nav_link("All (Search this)", rel_path, `${config.domain}/all.html`)}</span><!--
    --><span>${format_nav_link("Paginated", rel_path, `${config.domain}/1.html`)}</span><!--
    --><span>${format_nav_link("Playlists", rel_path, `${config.domain}/playlists.html`)}</span><!--
    --><!--<span class="search">
      <form  action="https://www.bing.com/" method="get">
        <input type="hidden" name="q" autocomplete="off" value="site:${config.domain}">
        <input type="text" name="q" autocomplete="off">
        <input type="submit" value="WIP Search">
      </form>
    </span>-->
  </nav>`
};
function format_nav_link(title, rel_path, target) {
  return rel_path == target
    ? `${title}`
    : `<a href="${target}">${title}</a>`
  ;
}

export function footer(config) {
  return `
  <footer>
    <div>
      Site designed <a href="https://aryailia.site/">Aryailia</a>.
      Content hosted with permission from <a href="http://a-bas-le-ciel.blogspot.com/">Eisel Mazard</a>.
    </div>
  </footer>`;
}


// https://stackoverflow.com/questions/3809401/
export function format_desc(text) {
  return text.split("\n").join("<br><br>")
    .replace(/https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)/g,
      match => `<a href="${match}">${match}</a>`);
  ;
};

export function ellipt(text, max_len) {
  return text.length > max_len
    ? text.substring(0, max_len - 3) + "..."
    : text;
};

export function format_date(date) {
  const year = date.substring(0, 4);
  const month = parseInt(date.substring(4, 6)) - 1;
  const day = date.substring(6, 8);
  const to_month_name = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  return `${day} ${to_month_name[month]} ${year}`;
};

