# Kódbázis Funkció Dokumentáció

## `main.dart`

**Fájl Célja:** Az alkalmazás belépési pontja. Beállítja a globális szolgáltatókat (providers), a témát és az ablakkezelést (asztali környezethez).

### Függvények:
*   `main()`: A fő belépési pont. Inicializálja a Flutter kötéseket (bindings), beállítja az ablakkezelőt (asztali gépen), inicializálja a `UserProvider`-t, és elindítja az alkalmazást.
*   `MainApp.build(BuildContext context)`: Felépíti a `MaterialApp`-ot, alkalmazza a témákat a `ThemeProvider` segítségével, és beállítja a kezdőképernyőt az `AuthGate`-re vagy a `TestTakingPage`-re (kioszk módban - logikai következtetés).
*   `AuthGate.build(BuildContext context)`: Körbeveszi az alkalmazás tartalmát. Ellenőrzi a hitelesítési státuszt; betöltő képernyőt mutat inicializálás közben, majd bejelentkezés esetén a `HomePage`-re, egyébként a `LoginPage`-re irányít.

---

## `api_service.dart`

**Fájl Célja:** Kezeli az összes hálózati kommunikációt a backend API-val.

### Függvények:
*   `login(String username, String password)`: Bejelentkezteti a felhasználót. Sikeres esetben JWT tokent ad vissza. Tartalmaz egy teszt mód gyorsbillentyűt.
*   `register(Map<String, dynamic> userData)`: Regisztrál egy új felhasználót a megadott adatokkal.
*   `getUserProfile(String token)`: Lekéri a jelenlegi felhasználó profiladatait a token használatával.
*   `updateUserProfile(String token, Map<String, dynamic> data)`: Frissíti a felhasználó profilinformációit.
*   `changePassword(String token, String currentPassword, String newPassword)`: Megváltoztatja a felhasználó jelszavát.
*   `deleteAccount(String token, String password)`: Törli a felhasználói fiókot a jelszó ellenőrzése után.
*   `changeEmail(String token, String newEmail, String password)`: Megváltoztatja a felhasználó e-mail címét.
*   `getUserGroups(String token)`: Lekéri azon csoportok listáját, amelyekhez a felhasználó tartozik.
*   `getGroupMembers(String token, int groupId)`: Lekéri egy adott csoport tagjainak listáját.
*   `removeMember(String token, int groupId, int userId)`: Eltávolít egy tagot a csoportból (csak admin).
*   `transferAdmin(String token, int groupId, int userId)`: Átruházza a csoport tulajdonjogát/adminisztrátori jogait egy másik tagra.
*   `joinGroup(String token, String inviteCode)`: Csatlakozás egy csoporthoz meghívókód használatával.
*   `createGroup(String token, String name, String color)`: Létrehoz egy új csoportot.
*   `leaveGroup(String token, int groupId)`: Kilépteti a jelenlegi felhasználót a csoportból.
*   `updateGroup(String token, int groupId, {String? name, String? color, bool? anticheat, bool? kiosk})`: Frissíti a csoport beállításait (név, szín, biztonsági opciók).
*   `regenerateInviteCode(String token, int groupId)`: Generál egy új meghívókódot a csoport számára.
*   `deleteGroup(String token, int groupId, String password)`: Véglegesen töröl egy csoportot.
*   `createProject(String token, String name, String description)`: Létrehoz egy új kvíz projektet/tervrajzot.
*   `createQuiz(String token, int projectId, int groupId, DateTime start, DateTime end)`: Ütemez egy kvízt egy projektből egy csoport számára.
*   `updateQuiz(String token, int quizId, DateTime start, DateTime end)`: Frissíti egy ütemezett kvíz időablakát.
*   `deleteQuiz(String token, int quizId)`: Töröl/lemond egy ütemezett kvízt.
*   `getGroupQuizzes(String token, int groupId)`: Lekéri a csoporthoz rendelt összes kvízt.
*   `getProjects(String token)`: Lekéri a felhasználó által létrehozott összes projektet.
*   `getProjectDetails(String token, int projectId)`: Részletes információkat kér le egy adott projektről (kérdések, beállítások).
*   `updateProject(String token, int projectId, Map<String, dynamic> data)`: Frissíti a projekt részleteit.
*   `deleteProject(String token, int projectId)`: Töröl egy projektet.
*   `searchUserBlocks(String token, String query, {String mode})`: Keres a kérdésbankban a lekérdezésnek megfelelő blokkok után.
*   `reportNetworkIssue({required String token, required int quizId, required String issueType})`: Naplózza a teszt során felmerült hálózati kapcsolati problémákat.

---

## `theme.dart`

**Fájl Célja:** Kezeli az alkalmazás témáját és stílusát.

### Függvények:
*   `AppTheme.lightTheme`: Statikus getter a szabványos világos téma adatokhoz.
*   `AppTheme.darkTheme`: Statikus getter a szabványos sötét téma adatokhoz.
*   `AppTheme.highContrastLight`: Statikus getter a nagy kontrasztú világos téma adatokhoz.
*   `AppTheme.highContrastDark`: Statikus getter a nagy kontrasztú sötét téma adatokhoz.
*   `ThemeProvider.toggleTheme(bool isDark)`: Vált a világos és sötét módok között.
*   `ThemeProvider.setThemeMode(ThemeMode mode)`: Közvetlenül beállítja a téma módot (rendszer, világos, sötét).
*   `ThemeProvider.setFontScale(double scale)`: Beállítja a globális betűméretezési tényezőt.
*   `ThemeProvider.toggleHighContrast(bool value)`: Engedélyezi vagy letiltja a nagy kontrasztú módot.
*   `ThemeProvider.toggleHapticFeedback(bool value)`: Engedélyezi vagy letiltja a haptikus visszajelzést.
*   `ThemeProvider.getThemeData()`: Visszaadja az aktuálisan aktív `ThemeData` objektumot a beállítások alapján.
*   `ThemeProvider._loadSettings()`: Betölti a téma preferenciákat a megosztott beállításokból (shared preferences).
*   `ThemeProvider._saveSettings()`: Elmenti az aktuális téma preferenciákat a tárhelyre.

---

## `providers/user_provider.dart`

**Fájl Célja:** Állapotkezelés a felhasználói hitelesítéshez és adatokhoz.

### Függvények:
*   `UserProvider.checkAutoLogin()`: Ellenőrzi a tárhelyen a mentett tokent, és megkísérli az automatikus bejelentkezést indításkor.
*   `UserProvider.login(String username, String password)`: Bejelentkezést hajt végre az `ApiService`-en keresztül és frissíti az állapotot.
*   `UserProvider.logout()`: Törli a felhasználói adatokat és a tokent, kezeli a kijelentkezést.
*   `UserProvider.register(Map<String, dynamic> userData)`: Proxy az `ApiService.register` metódushoz.
*   `UserProvider.fetchUserProfile()`: Frissíti a felhasználói profiladatokat az API-ból.
*   `UserProvider.updateUserProfile(Map<String, dynamic> data)`: Frissíti a helyi és távoli felhasználói profilt.
*   `UserProvider.changePassword(String currentPassword, String newPassword)`: Jelszót változtat az API-n keresztül.
*   `UserProvider.changeEmail(String newEmail, String password)`: E-mail címet változtat az API-n keresztül.
*   `UserProvider.deleteAccount(String password)`: Törli a felhasználói fiókot.
*   `UserProvider._setToken(String token)`: Belső segédfüggvény a hitelesítési token mentéséhez a megosztott beállításokba.
*   `UserProvider._clearToken()`: Belső segédfüggvény a hitelesítési token törléséhez a megosztott beállításokból.

---

## `models/user.dart`

**Fájl Célja:** Adatmodell osztály a Felhasználó számára.

### Függvények:
*   `User.fromJson(Map<String, dynamic> json)`: Gyári konstruktor egy `User` példány létrehozásához JSON map-ből.
*   `User.toJson()`: Visszaalakítja a `User` példányt JSON map-pé.
*   `User.copyWith(...)`: Létrehoz egy másolatot a `User` objektumról frissített mezőkkel.

---

## `login_page.dart`

**Fájl Célja:** Kezeli a felhasználói bejelentkezési és regisztrációs folyamatokat.

### Függvények:
*   `_LoginPageState.initState()`: Inicializálja az animációkat és a vezérlőket.
*   `_LoginPageState.dispose()`: Takarítja a vezérlőket.
*   `_LoginPageState._handleLogin()`: Validálja a bejelentkezési űrlapot és meghívja a `UserProvider.login`-t. Kezeli a siker/hiba visszajelzést.
*   `_LoginPageState._handleRegister()`: Validálja a regisztrációs űrlapot és meghívja a `UserProvider.register`-t.
*   `_LoginPageState._resetRegistrationState()`: Visszaállítja a regisztrációs léptetőt (stepper) az elejére.
*   `_LoginPageState._checkPasswordStrength(String? password)`: Elemzi a jelszó összetettségét és frissíti az erősségjelzőt.
*   `_LoginPageState._updateRegisterButtonState()`: Engedélyezi/letiltja a regisztráció gombot az űrlap érvényessége alapján.
*   `_LoginPageState._nextPage()`: A következő lépésre lép a regisztrációs léptetőben.
*   `_LoginPageState._previousPage()`: Az előző lépésre lép a regisztrációs léptetőben.
*   `_LoginPageState.build(BuildContext context)`: Felépíti a fő bejelentkezési/regisztrációs felületet az animált váltóval.
*   `_LoginPageState._buildAppBar(...)`: Felépíti a felső alkalmazássávot.
*   `_LoginPageState._buildBackgroundWave(...)`: Felépíti az animált hullám hátteret.
*   `_LoginPageState._buildLoginForm(...)`: Felépíti a bejelentkezési űrlap widgetet.
*   `_LoginPageState._buildRegisterStepper(...)`: Felépíti a többlépéses regisztrációs widgetet.
*   `_LoginPageState._buildAvatarSelector(...)`: Felépíti az avatárválasztó rácsot.
*   `_LoginPageState._buildStep(...)`: Segédfüggvény egyetlen regisztrációs lépés felépítéséhez.
*   `PasswordStrengthIndicator.build(...)`: Megjeleníti a jelszóerősség vizualizációt.
*   `PasswordRequirements.build(...)`: Megjeleníti a jelszókövetelmények listáját.

---

## `home_page.dart`

**Fájl Célja:** A fő vezérlőpult hitelesített felhasználók számára.

### Függvények:
*   `_HomePageState.initState()`: Inicializálja az adatlekérést a csoportokhoz és az aktív tesztekhez.
*   `_HomePageState._getActiveTests()`: Lekéri az aktív teszteket az összes felhasználói csoporthoz.
*   `_HomePageState._fetchGroups()`: Lekéri a felhasználó csoportjait az API-ból.
*   `_HomePageState._handleTestExpired(ActiveTestItem expiredItem)`: Visszahívás (callback), amikor lejár a teszt időzítője.
*   `_HomePageState._selectGroup(Group group)`: A kiválasztott csoport részletes nézetére navigál (asztali).
*   `_HomePageState._showJoinGroupDialog()`: Megjelenít egy párbeszédablakot a csoportmeghívó kód megadásához.
*   `_HomePageState._toggleSpeedDial()`: Ki-/bekapcsolja a lebegő műveleti gomb menüjének láthatóságát.
*   `_HomePageState.build(BuildContext context)`: Felépíti a fő vázat, beleértve az oldalsó navigációt (asztali) és a fő tartalmi területet.
*   `_HomePageState._buildAnimatedContent()`: Felépíti a tartalmi területet átmeneti animációkkal.
*   `_HomePageState._buildSpeedDial(...)`: Felépíti az általános speed dial menüt.
*   `_HomePageState._buildMenuButton(...)`: Segédfüggvény gombok építéséhez a speed dial menün belül.
*   `_HomePageState._buildGroupList()`: Megjeleníti a `GroupCard` widgetek rácsát/listáját.
*   `_HomePageState._buildSideNav(...)`: Felépíti az oldalsó navigációs módszereket (asztali) vagy a fiókot (mobil).
*   `SideNavItem.build(BuildContext context)`: Megjelenít egy elemet az oldalsó navigációban.
*   `ActiveTestCard._showStartTestConfirmation(...)`: Megerősítő párbeszédablakot mutat a teszt megkezdése előtt.
*   `ActiveTestCard.build(BuildContext context)`: Megjeleníti az aktív tesztet mutató kártyát.
*   `_ActiveTestCarouselState.build(...)`: Megjeleníti az aktív tesztek körhinta-szerű (carousel) nézetét.

---

## `projects_page.dart`

**Fájl Célja:** Kezeli és listázza a felhasználó által létrehozott projekteket (tervezési fázisban lévő kvízek).

### Függvények:
*   `_ProjectsPageState._hungarianNormalize(String s)`: Segédfüggvény stringek normalizálásához a rendezéshez (magyar karakterek kezelése).
*   `_ProjectsPageState._loadSortPreference()`: Betölti a preferált rendezési módszert (név, dátum) a tárhelyről.
*   `_ProjectsPageState._saveSortPreference(String value)`: Elmenti a rendezési preferenciát.
*   `_ProjectsPageState._fetchProjects()`: Meghívja az `ApiService.getProjects`-et a lista betöltéséhez.
*   `_ProjectsPageState._deleteProject(int projectId, String name)`: Megerősítést kér, majd meghívja az `ApiService.deleteProject`-et.
*   `_ProjectsPageState._duplicateProject(Map<String, dynamic> project)`: Létrehoz egy másolatot egy meglévő projektről.
*   `_ProjectsPageState._buildInlineActionButton(...)`: Segédfüggvény projekt műveleti gombok építéséhez.
*   `_ProjectsPageState.build(BuildContext context)`: Megjeleníti a projektek listáját, a keresősávot és a rendezési vezérlőket.

---

## `project_editor_page.dart`

**Fájl Célja:** Felület kvízkérdések és struktúra létrehozásához és szerkesztéséhez.

### Függvények:
*   `_ProjectEditorPageState._onBankSearchChanged(String query)`: Frissíti a keresési lekérdezést a kérdésbankhoz.
*   `_ProjectEditorPageState._saveValidState()`: Elmenti az aktuális állapotot a visszavonás/mégis (undo/redo) funkcióhoz.
*   `_ProjectEditorPageState._validateBlock(Map<String, dynamic> block)`: Validál egyetlen kérdésblokkot (ellenőrzi a kérdés szövegét, a válaszokat, a helyes választ).
*   `_ProjectEditorPageState._validateAll()`: Validálja az összes blokkot a projektben.
*   `_ProjectEditorPageState._showValidationErrorDialog(...)`: Hibákat jelenít meg, ha a validálás sikertelen.
*   `_ProjectEditorPageState._undo()`: Visszavonja az utolsó módosítást.
*   `_ProjectEditorPageState._redo()`: Újraalkalmaz egy visszavont módosítást.
*   `_ProjectEditorPageState._performBankSearch(String query)`: Keres a kérdésbankban az API-n keresztül.
*   `_ProjectEditorPageState._fetchProjectDetails()`: Betölt egy meglévő projektet szerkesztésre.
*   `_ProjectEditorPageState._addQuestionFromBank(...)`: Hozzáad egy kiválasztott kérdést a bankból a jelenlegi projekthez.
*   `_ProjectEditorPageState._saveProject()`: Validálja és elmenti a projektet a szerverre az `ApiService`-en keresztül.
*   `_ProjectEditorPageState._addQuestion()`: Hozzáad egy új, üres kérdésblokkot.
*   `_ProjectEditorPageState._confirmDeleteProject()`: Törli a teljes projektet.
*   `_ProjectEditorPageState._addQuestionBlock(String type)`: Általános metódus egy adott típusú kérdés hozzáadásához.
*   `_ProjectEditorPageState._addTrueFalseQuestion()`, `_addMatchingQuestion()`, `_addOrderingQuestion()`, stb.: Specifikus segédfüggvények különböző kérdéstípusok hozzáadásához.
*   `_ProjectEditorPageState._buildSentenceOrderingAnswers(...)`: UI építő mondatrendezés specifikus bemenetekhez.
*   `_ProjectEditorPageState._buildMatchingAnswers(...)`: UI építő párosító kérdés bemenetekhez.

---

## `group_page.dart`

**Fájl Célja:** Egy adott csoport részletes nézete, tagok és ütemezett kvízek kezelése.

### Függvények:
*   `Group.copyWith(...)`: Segédfüggvény a Group immutábilis objektumok frissítéséhez.
*   `Group.getGradient(...)`, `Group.getTextColor(...)`: Vizuális segédfüggvények a csoport stílusához.
*   `_GroupPageState._fetchMembers()`: Betölti a csoporttagokat az API-ból.
*   `_GroupPageState._buildHeader()`: Felépíti a vizuális fejlécet a csoportinformációkkal és statisztikákkal.
*   `_GroupPageState._buildHeroActiveTestCard(...)`: Megjeleníti a legkiemelkedőbb aktív tesztet.
*   `_GroupPageState.openAdmin()`: Navigál a csoport admin/osztályozó felületére.
*   `_GroupPageState._buildTestContent()`: Füles nézet az Aktív, Jövőbeli és Múltbeli kvízekhez.
*   `_GroupPageState._fetchQuizzes(...)`: Betölti a kvízeket a csoporthoz.
*   `_GroupPageState._startQuizNow(...)`: Elindítja a tesztkitöltési folyamatot egy diák számára.
*   `_GroupPageState._showStartTestConfirmation(...)`: Biztonsági és megerősítő párbeszédablak indítás előtt.
*   `_GroupPageState._showQuizOptions(...)`: Admin opciók egy adott kvízhez (szerkesztés, törlés, jelentés).
*   `_GroupPageState._removeMember(int userId)`: Eltávolít egy felhasználót a csoportból.
*   `_GroupPageState._showDeleteQuizConfirmation(...)`: Töröl egy ütemezett kvízt.

---

## `create_group_page.dart`

**Fájl Célja:** Felület új tanulócsoport létrehozásához.

### Függvények:
*   `_CreateGroupPageState._buildHeader(...)`: Megjeleníti az oldal fejlécét.
*   `_CreateGroupPageState._buildDesktopLayout(...)`: Elrendezés nagyobb képernyőkhöz.
*   `_CreateGroupPageState._buildMobileLayout(...)`: Elrendezés kisebb képernyőkhöz.
*   `_CreateGroupPageState._buildForm(...)`: A beviteli rlap a csoport nevéhez, színéhez stb.
*   `_CreateGroupPageState._buildColorPicker(...)`: UI a csoport színtémájának kiválasztásához.
*   `_CreateGroupPageState._buildHSLSliders(...)`: Egyéni színhangolás.
*   `_CreateGroupPageState._buildProtectionSlider(...)`: UI a biztonsági szint kiválasztásához (Nyitott, Védett, Zárolt).
*   `_CreateGroupPageState._buildPreview(...)`: A csoportkártya élő előnézete.
*   `_CreateGroupPageState._createGroup()`: Elküldi az adatokat az `ApiService.createGroup`-nak.

---

## `create_project_dialog.dart`

**Fájl Célja:** Párbeszédablak új projekt inicializálásához.

### Függvények:
*   `CreateProjectDialog.build(BuildContext context)`: Megjeleníti a párbeszédablakot a név és leírás mezőkkel.
*   `CreateProjectDialog._onCreated()`: Visszaadja az új projekt adatait a hívónak.

---

## `create_quiz_dialog.dart`

**Fájl Célja:** Párbeszédablak kvíz ütemezéséhez egy projektből.

### Függvények:
*   `_CreateQuizDialogState._fetchProjects()`: Betölti az elérhető projekteket a kiválasztáshoz.
*   `_CreateQuizDialogState._pickDateTime(...)`: Dátumtartomány-választó a kvíz elérhetőségéhez.
*   `_CreateQuizDialogState._save()`: Meghívja az `ApiService.createQuiz`-t vagy az `updateQuiz`-t.

---

## `test_taking_page.dart`

**Fájl Célja:** A központi kvízfelület, kezeli a teszt renderelését és a biztonságot.

### Függvények:
*   `_TestTakingPageState._generateMockQuestions()`: Tartalék adatokat biztosít teszteléshez.
*   `_TestTakingPageState._initializeWebView()`: Beállítja a belső böngészőt a kérdésekben lévő webes tartalmakhoz.
*   `_TestTakingPageState._initQuestions()`: Előkészíti a kérdéssort.
*   `_TestTakingPageState._enableScreenshotProtection()`, `_disableScreenshotProtection()`: Ki-/bekapcsolja a képernyőfelvétel elleni védelmet (platformspecifikus).
*   `_TestTakingPageState._setupAdvancedProtections()`: Konfigurálja az operációs rendszer szintű védelmeket (fókuszvesztés, stb.).
*   `_TestTakingPageState._handleDesktopKeyEvent(...)`: Elfogja és blokkolja a tiltott billentyűparancsokat (Alt+Tab, stb.).
*   `_TestTakingPageState._clearClipboard()`: Törli a rendszer vágólapját a beillesztés megakadályozására.
*   `_TestTakingPageState._muteVolume()`: Némítja a rendszerhangot (ha szükséges).
*   `_TestTakingPageState._enterFullscreen()`, `_exitFullscreen()`: Kezeli a teljes képernyős mód kikényszerítését.
*   `_TestTakingPageState._enableKioskModeWithRetry()`: Kikényszeríti a kioszk módot, ismételten felszólítva a felhasználót, ha megpróbál kilépni.
*   `_TestTakingPageState._triggerAntiCheat()`: A szabálysértés észlelésekor végrehajtott logika (esemény naplózása, esetleg teszt befejezése).
*   `_TestTakingPageState._showAntiCheatDialog()`: Figyelmeztetés a felhasználónak szabálysértés esetén.
*   `_TestTakingPageState._calculateProgress()`: Frissíti a folyamatjelző sávot.
*   `_TestTakingPageState.build(...)`: Megjeleníti a kérdésfelületet, a jegyzettömböt és a védelmi rétegeket.

---

## `admin_page.dart`

**Fájl Célja:** Tanári vezérlőpult az aktív vizsgák figyeléséhez és osztályozáshoz.

### Függvények:
*   `_AdminPageState._fetchProjectDetails()`: Betölti a kvízadatokat.
*   `_AdminPageState._generateMockAnswers()`: Hamis adatokat hoz létre UI teszteléshez.
*   `_AdminPageState._buildSidebar(...)`: Navigációs oldalsáv.
*   `_AdminPageState._buildGradesSection(...)`: Vizualizálja a jegyeloszlást és a statisztikákat.
*   `_AdminPageState._buildSubmittedExamsSection(...)`: Listázza a diákok beadott munkáit ellenőrzésre.
*   `_AdminPageState._buildMonitoringSection(...)`: Valós idejű műszerfal a tesztet éppen író diákokról.
*   `_AdminPageState._buildDashboardBar(...)`: Felső lépések/státusz áttekintés.
*   `_AdminPageState._buildExportSection(...)`: Konfiguráció PDF vagy CSV jelentések generálásához.

---

## `grading_view.dart`

**Fájl Célja:** Felület a diákok válaszainak kézi osztályozásához és áttekintéséhez.

### Függvények:
*   `_GradingViewState._loadMockData()`: Betölti a beadott adatokat.
*   `_GradingViewState._saveChanges()`: Véglegesíti a jegymódosításokat.
*   `_GradingViewState._buildQuestionCard(...)`: Megjelenít egyetlen diákválaszt a helyes válasszal való összehasonlítással.
*   `_GradingViewState._buildPointsEditor(...)`: Widget a pontszámok módosításához egy adott válasznál.
*   `_GradingViewState._buildStatisticsPanel()`: Statisztikákat mutat az adott diákról/beadásról.
*   `_GradingViewState._buildStudentListBox(...)`: Lista a különböző diákok vizsgái közötti navigáláshoz.
*   `_GradingViewState._buildGradeSettingsPanel(...)`: Konfiguráció a jegyhatárokhoz (pl. % szükséges az 5-öshöz).

---

## `settings_page.dart`

**Fájl Célja:** Felhasználói beállítások és fiókkezelés.

### Függvények:
*   `_SettingsPageState._buildGeneralSettings(...)`: Téma és nyelvi opciók.
*   `_SettingsPageState._buildProfileSettings(...)`: Felhasználói profil szerkesztése (név, avatár).
*   `_SettingsPageState._showChangePasswordDialog(...)`: UI jelszófrissítéshez.
*   `_SettingsPageState._showDeleteAccountDialog(...)`: UI fióktörléshez.
*   `_SettingsPageState._showEditProfileDialog(...)`: Párbeszédablak név és becenév szerkesztéséhez.
*   `_SettingsPageState._buildNotificationSettings(...)`: Kapcsoló az alkalmazásértesítésekhez.
*   `_SettingsPageState._buildAccessibilitySettings(...)`: Opciók nagy kontraszthoz, betűmérethez.

---

## `services/pdf_service.dart`

**Fájl Célja:** PDF jelentéseket generál.

### Függvények:
*   `generateGradesReport(...)`: Fő függvény a PDF felépítéséhez. Fogadja a diákadatokat, statisztikákat és formázási opciókat (kérdések, válaszkulcs stb. belefoglalása).
*   `_buildStatItem(...)`: Segédfüggvény statisztikák formázásához a PDF-ben.
*   `_buildTableCell(...)`: Segédfüggvény a táblázat elrendezéséhez.
*   `getStatusColor(...)`: Megfelelteti a megfelelt/nem felelt meg státuszt PDF színeknek.
*   `getStudentName(...)`: Segédfüggvény a diáknevek formázásához.

---

## `utils/web_protections.dart`
**Fájl Célja:** Feltételes export fájl.
*   Nincsenek függvények (csak export).

---

## `utils/web_protections_stub.dart`
**Fájl Célja:** Védelmek üres ("no-op") implementációja nem webes platformokra.
### Függvények:
*   `setup(...)`: Üres metódus.
*   `enterFullScreen()`: Üres metódus.
*   `exitFullScreen()`: Üres metódus.

---

## `utils/web_protections_web.dart`
**Fájl Célja:** Web-specifikus csalásmegelőzés JavaScript injektálással.

### Függvények:
*   `setup(...)`: JS-t injektál a jobb klikk, F12, másolás/beillesztés blokkolására és a lapváltás/fókuszvesztés észlelésére.
*   `enterFullScreen()`: Kéri a böngésző teljes képernyős módját.
*   `exitFullScreen()`: Kilép a böngésző teljes képernyős módjából.
