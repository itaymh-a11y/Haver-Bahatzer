class AppStrings {
  AppStrings._();

  // App
  static const appName = 'חבר בחצר';

  // Auth
  static const email = 'אימייל';
  static const password = 'סיסמה';
  static const login = 'התחברות';
  static const logout = 'התנתקות';
  static const loginTitle = 'ברוכים הבאים';
  static const loginSubtitle = 'התחבר לניהול הפנסיון';

  // Auth errors
  static const authErrorWrongPassword = 'הסיסמה שגויה. אנא נסה שנית.';
  static const authErrorUserNotFound = 'משתמש לא נמצא.';
  static const authErrorInvalidEmail = 'כתובת אימייל לא תקינה.';
  static const authErrorTooManyRequests = 'יותר מדי ניסיונות. נסה שוב מאוחר יותר.';
  static const authErrorNetworkFailed = 'שגיאת רשת. בדוק את החיבור לאינטרנט.';
  static const authErrorGeneral = 'שגיאת התחברות. נסה שנית.';

  // Validation
  static const fieldRequired = 'שדה חובה';
  static const emailInvalid = 'אימייל לא תקין';
  static const passwordTooShort = 'הסיסמה חייבת להכיל לפחות 6 תווים';
  static const phoneInvalid = 'מספר טלפון לא תקין';

  // Dogs
  static const dogs = 'כלבים';
  static const addDog = 'הוסף כלב';
  static const editDog = 'ערוך כלב';
  static const deleteDog = 'מחק כלב';
  static const dogName = 'שם הכלב';
  static const breed = 'גזע';
  static const ownerName = 'שם הבעלים';
  static const ownerPhone = 'טלפון הבעלים';
  static const notes = 'הערות';
  static const dogPhoto = 'תמונת כלב';
  static const tags = 'תגיות';
  static const noDogs = 'אין כלבים עדיין';
  static const noDogsSubtitle = 'לחץ על + כדי להוסיף כלב חדש';
  static const searchDogs = 'חפש לפי שם כלב או בעלים';
  static const filterByTag = 'סנן לפי תגית';
  static const saveChanges = 'שמור שינויים';
  static const addNewDog = 'הוסף כלב';
  static const dogDeleted = 'הכלב נמחק בהצלחה';
  static const dogAdded = 'הכלב נוסף בהצלחה';
  static const dogUpdated = 'הכלב עודכן בהצלחה';
  static const confirmDelete = 'האם אתה בטוח?';
  static const confirmDeleteMessage = 'פעולה זו תמחק את הכלב לצמיתות.';
  static const cancel = 'ביטול';
  static const confirm = 'אישור';
  static const delete = 'מחיקה';
  static const callOwner = 'התקשר לבעלים';
  static const addPhoto = 'הוסף תמונה';
  static const changePhoto = 'שנה תמונה';
  static const photoFromCamera = 'מצלמה';
  static const photoFromGallery = 'גלריה';
  static const age = 'גיל';
  static const ageYears = 'שנים';

  // Dashboard
  static const dashboard = 'לוח בקרה';
  static const manageDogs = 'ניהול כלבים';

  // Bookings
  static const bookings = 'הזמנות';
  static const booking = 'הזמנה';
  static const addBooking = 'הוסף הזמנה';
  static const editBooking = 'ערוך הזמנה';
  static const calendar = 'לוח שנה';
  static const vacations = 'חופשות';
  static const addVacation = 'הוסף חופשה';
  static const editVacation = 'ערוך חופשה';
  static const vacationLabel = 'שם החופשה (אופציונלי)';
  static const noVacations = 'אין חופשות מתוכננות';
  static const noVacationsSubtitle = 'לחץ על + כדי לחסום תאריכים לאירוח';
  static const vacationDay = 'יום חופשה';
  static const confirmDeleteVacation = 'למחוק את החופשה?';
  static const vacationOverlapBookingsTitle = 'יש הזמנות אירוח בטווח זה';
  static const vacationOverlapBookingsMessage =
      'בתאריכים שבחרת כבר קיימות הזמנות אירוח. האם ליצור את החופשה בכל זאת?';
  static const conflictVacation =
      'לא ניתן לשבץ אירוח בתאריכי חופשה';
  static const introDuringVacationTitle = 'שים לב — יום חופשה';
  static const introDuringVacationMessage =
      'תאריך הפגישה נופל על ימי חופשה. האם לשמור את פגישת ההיכרות בכל זאת?';
  static const createVacationAnyway = 'צור חופשה';
  static const bookingType = 'סוג הזמנה';
  static const boarding = 'אירוח';
  static const introMeeting = 'פגישת היכרות';
  static const kennel = 'כלוב';
  static const startDate = 'תאריך כניסה';
  static const endDate = 'תאריך יציאה';
  static const date = 'תאריך';
  static const meetingTime = 'שעת פגישה';
  static const totalPrice = 'מחיר כולל';
  static const isPaid = 'שולם';
  static const unpaid = 'לא שולם';
  static const partiallyPaid = 'שולם חלקית';
  static const splitPayment = 'פיצול תשלום';
  static const amountPaidNow = 'סכום ששולם כעת';
  static const amountRemaining = 'יתרה';
  static const paymentDate = 'תאריך תשלום';
  static const paymentSummary = 'סיכום תשלום';
  static const paymentBreakdown = 'פירוט תשלומים';
  static const chargeCheckoutDay = 'להחשיב את יום היציאה במחיר';
  static const bookingDailyRate = 'מחיר יומי להזמנה';
  static const changeDailyRateMidStay = 'שינוי מחיר יומי באמצע השהייה';
  static const newDailyRate = 'מחיר יומי חדש';
  static const changeKennelMidStay = 'העברת כלוב במהלך השהות';
  static const kennelChangeStartDate = 'תאריך מעבר';
  static const newKennel = 'כלוב חדש';
  static const initialKennel = 'כלוב בהתחלה';
  static const kennelChangeDateInvalid =
      'תאריך המעבר חייב להיות אחרי תאריך הכניסה';
  static const kennelChangeSameKennel = 'יש לבחור כלוב שונה מהכלוב הראשוני';
  static const rateChangeStartDate = 'החל מתאריך';
  static const paymentMethod = 'אמצעי תשלום';
  static const bit = 'ביט';
  static const cash = 'מזומן';
  static const bankTransfer = 'העברה בנקאית';
  static const todayCheckIns = 'כניסות היום';
  static const todayCheckOuts = 'יציאות היום';
  static const todayIntros = 'פגישות היכרות היום';
  static const occupancy = 'תפוסה';
  static const unitsFreeOf = 'יחידות תפוסות מתוך';
  static const noBookings = 'אין הזמנות';
  static const statusUpcoming = 'מתוכנן';
  static const statusActive = 'פעיל';
  static const statusCompleted = 'הסתיים';
  static const bookingAdded = 'ההזמנה נוספה בהצלחה';
  static const bookingUpdated = 'ההזמנה עודכנה בהצלחה';
  static const bookingDeleted = 'ההזמנה נמחקה בהצלחה';
  static const confirmDeleteBooking = 'פעולה זו תמחק את ההזמנה לצמיתות.';
  static const conflictDog = 'אחד הכלבים כבר מוזמן בתאריכים אלו';
  static const conflictKennel = 'הכלוב מלא בתאריכים אלו';
  static const conflictSameOwner =
      'בכלוב זה ניתן לארח כלבים מאותו בעלים בלבד';

  static String kennelMaxDogsExceeded(int max) =>
      'ניתן לבחור עד $max כלבים בכלוב זה';
  static const sameDayTurnoverTitle = 'שים לב';
  static const sameDayTurnoverMessage =
      'בתא שבחרת יש כלב אחר שמתוכנן לצאת באותו היום. האם להמשיך בכל זאת?';
  static const continueAction = 'המשך';
  static const missingContract = 'חסר חוזה!';
  static const snapContract = 'צלם חוזה';
  static const retakeContract = 'צלם מחדש';
  static const contractUploaded = 'החוזה הועלה בהצלחה';
  static const viewContract = 'הצג חוזה';
  static const selectDogs = 'בחר כלבים';
  static const dailyRate = 'מחיר ליום';
  static const selectOwner = 'בחר בעלים';
  static const createNewOwner = 'צור בעלים חדש';

  // Financials
  static const financials = 'דוחות כספיים';

  // Pension products
  static const pensionProducts = 'מוצרי פנסיון';
  static const productLibrary = 'ספריית מוצרים';
  static const supplierOrders = 'הזמנות לספק';
  static const addProduct = 'הוסף מוצר';
  static const editProduct = 'ערוך מוצר';
  static const productName = 'שם המוצר';
  static const productPrice = 'מחיר ליחידה';
  static const noProducts = 'אין מוצרים בספרייה';
  static const noProductsSubtitle = 'הוסף מוצרים עם תמונה ומחיר לשימוש בהזמנות';
  static const newSupplierOrder = 'הזמנה חדשה לספק';
  static const finishOrder = 'סיום הזמנה';
  static const orderSummary = 'סיכום הזמנה';
  static const orderSaved = 'ההזמנה נשמרה';
  static const copyOrderText = 'העתק טקסט להזמנה';
  static const orderCopied = 'הטקסט הועתק ללוח';
  static const sendViaWhatsapp = 'שלח בוואטסאפ';
  static const noOrders = 'אין הזמנות שמורות';
  static const noOrdersSubtitle = 'צור הזמנה חדשה ובחר מוצרים מהספרייה';
  static const orderItems = 'פריטים בהזמנה';
  static const quantity = 'כמות';
  static const orderNotes = 'הערות להזמנה (אופציונלי)';
  static const selectAtLeastOneProduct = 'יש לבחור לפחות מוצר אחד';
  static const confirmDeleteProduct = 'למחוק את המוצר?';
  static const confirmDeleteOrder = 'למחוק את ההזמנה?';
  static const productAdded = 'המוצר נוסף בהצלחה';
  static const productUpdated = 'המוצר עודכן בהצלחה';
  static const productDeleted = 'המוצר נמחק';

  static const revenue = 'הכנסות';
  static const debtTracker = 'מעקב חובות';
  static const noUnpaid = 'אין חובות פתוחים';
  static const avgDogsPerWeek = 'ממוצע כלבים בשבוע';
  static const peakDay = 'יום עמוס ביותר';
  static const statistics = 'סטטיסטיקות';

  // General
  static const error = 'שגיאה';
  static const retry = 'נסה שנית';
  static const loading = 'טוען...';
  static const save = 'שמור';
  static const close = 'סגור';
  static const back = 'חזור';
}
