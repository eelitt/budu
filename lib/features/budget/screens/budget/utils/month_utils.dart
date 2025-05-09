String getMonthName(int month) {
  switch (month) {
    case 1:
      return 'Tammikuu';
    case 2:
      return 'Helmikuu';
    case 3:
      return 'Maaliskuu';
    case 4:
      return 'Huhtikuu';
    case 5:
      return 'Toukokuu';
    case 6:
      return 'Kesäkuu';
    case 7:
      return 'Heinäkuu';
    case 8:
      return 'Elokuu';
    case 9:
      return 'Syyskuu';
    case 10:
      return 'Lokakuu';
    case 11:
      return 'Marraskuu';
    case 12:
      return 'Joulukuu';
    default:
      return 'Tuntematon';
  }
}