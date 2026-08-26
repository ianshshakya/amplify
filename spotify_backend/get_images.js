const artists = ['Arijit Singh','Shreya Ghoshal','Kishore Kumar','Lata Mangeshkar','Udit Narayan','Alka Yagnik','Kumar Sanu','AR Rahman','KK','Sonu Nigam','Badshah','Diljit Dosanjh','AP Dhillon','Taylor Swift','The Weeknd','Justin Bieber','Ed Sheeran','Drake','Eminem','Billie Eilish','Ariana Grande','Post Malone','Dua Lipa','Bruno Mars']; 
Promise.all(artists.map(kw => fetch('https://www.jiosaavn.com/api.php?__call=search.getArtistResults&q=' + encodeURIComponent(kw) + '&_format=json&_marker=0&ctx=web6dot0').then(r=>r.json()).then(d => ({ kw, img: d.results[0].image.replace('50x50', '500x500') })))).then(res => { 
  let out=''; 
  res.forEach(r => out += `ArtistInfo('${r.kw}', '${r.img}'),\n`); 
  console.log(out); 
});
