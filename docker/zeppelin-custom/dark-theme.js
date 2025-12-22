/* Force Dark Theme pour tous les utilisateurs */
(function() {
  // Attendre que le DOM soit chargé
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyDarkTheme);
  } else {
    applyDarkTheme();
  }
  
  function applyDarkTheme() {
    // Injecter le dark theme dans le localStorage
    if (typeof(Storage) !== "undefined") {
      localStorage.setItem('zeppelin.setting.theme', 'dark');
    }
    
    // Appliquer immédiatement le dark theme
    document.body.classList.add('dark-theme');
    document.documentElement.setAttribute('data-theme', 'dark');
  }
})();
