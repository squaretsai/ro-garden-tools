(function () {
  const key = document.body.dataset.dungeon;
  const data = window.dungeonGuides && window.dungeonGuides[key];

  if (!data) {
    document.body.innerHTML = "<main style='padding:24px;font-family:sans-serif'>找不到副本資料。</main>";
    return;
  }

  const monsterImage = (id) => `https://static.divine-pride.net/images/mobs/png/${id}.png`;
  const navi = (coord) => {
    const parts = coord.split(/\s+/);
    return parts.length >= 3 ? `/navi ${parts[0]}/${parts[1]}/${parts[2]}` : coord;
  };

  document.title = `RO樂園 ${data.title}副本攻略`;
  document.querySelector(".hero").style.backgroundImage = `url("${data.hero}")`;
  document.querySelector("#page-title").textContent = data.title;
  document.querySelector("#page-subtitle").textContent = data.subtitle;
  document.querySelector("#page-description").textContent = data.description;

  document.querySelector("#facts").innerHTML = data.facts.map(([label, value]) => `
    <div class="fact"><span>${label}</span><strong>${value}</strong></div>
  `).join("");

  document.querySelector("#routeGrid").innerHTML = data.route.map(([title, text], index) => `
    <article class="card route-card">
      <div class="route-num">${index + 1}</div>
      <h3>${title}</h3>
      <p>${text}</p>
    </article>
  `).join("");

  document.querySelector("#monsterGrid").innerHTML = data.monsters.map(([id, name, level, meta]) => `
    <a class="monster-card" href="https://twroz.wiki/mob?search_query=${id}" target="_blank" rel="noreferrer">
      <span class="monster-art"><img src="${monsterImage(id)}" alt="${name}" loading="lazy"></span>
      <span>
        <span class="monster-name">${name}</span>
        <span class="chips"><span class="chip">${level}</span><span class="chip">${meta}</span></span>
      </span>
    </a>
  `).join("");

  document.querySelector("#rewardGrid").innerHTML = data.rewards.map(([title, text]) => `
    <article class="card reward-card">
      <h3>${title}</h3>
      <p>${text}</p>
    </article>
  `).join("");

  document.querySelector("#npcGrid").innerHTML = data.navis.map(([name, coord]) => `
    <article class="card npc-card">
      <h3>${name}</h3>
      <span class="coord">${navi(coord)}</span>
      <p>${coord}</p>
    </article>
  `).join("");

  document.querySelector("#equipmentGrid").innerHTML = data.equipment.map(([title, text]) => `
    <article class="card reward-card">
      <h3>${title}</h3>
      <p>${text}</p>
    </article>
  `).join("");

  document.querySelector("#notes").innerHTML = data.notes.map((note) => `<div class="note">${note}</div>`).join("");

  document.querySelector("#galleryGrid").innerHTML = data.images.map(([src, caption]) => `
    <figure>
      <img src="${src}" alt="${caption}" loading="lazy">
      <figcaption>${caption}</figcaption>
    </figure>
  `).join("");

  document.querySelector("#sources").innerHTML = data.sources.map(([label, url]) => `
    <a href="${url}" target="_blank" rel="noreferrer">${label}</a>
  `).join("");
}());
