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
  static const conflictKennel = 'הכלוב כבר תפוס בתאריכים אלו';
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
