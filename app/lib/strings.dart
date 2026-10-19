import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All user-facing wording lives here so it is easy to change.
/// Every string has a Hindi and an English version; Hindi is the default.
class S {
  /// 'hi' or 'en'. The app rebuilds when this changes.
  static final lang = ValueNotifier<String>('hi');

  static bool get isHindi => lang.value == 'hi';
  static String _t(String hi, String en) => isHindi ? hi : en;

  static Future<void> loadLang() async {
    final p = await SharedPreferences.getInstance();
    lang.value = p.getString('lang') == 'en' ? 'en' : 'hi';
  }

  static Future<void> setLang(String code) async {
    lang.value = code == 'en' ? 'en' : 'hi';
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', lang.value);
  }

  static Future<void> toggleLang() => setLang(isHindi ? 'en' : 'hi');

  static String get language => _t('भाषा', 'Language');
  static String get switchLang => _t('English', 'हिन्दी');
  static String get appName => _t('रिपेयरवाला', 'Repairwala');
  static String get settings => _t('सेटिंग', 'Settings');
  static String get serverAddress => _t(
    'सर्वर का पता (जैसे http://192.168.1.5:3000)',
    'Server address (e.g. http://192.168.1.5:3000)',
  );
  static String get shopToken => _t('दुकान का टोकन', 'Shop token');
  static String get check => _t('जाँचें', 'Check');
  static String get save => _t('सेव करें', 'Save');
  static String get saved => _t('सेव हो गया', 'Saved');
  static String get server => _t('सर्वर', 'Server');
  static String get whisper => _t('आवाज़ पहचान', 'Speech recognition');
  static String get ollama => _t('समझने वाला (Gemma)', 'Understanding (Gemma)');
  static String get tts => _t('आवाज़ संदेश', 'Voice message');
  static String get upi => 'UPI';
  static String get search =>
      _t('फ़ोन, नाम या गाँव खोजें', 'Search phone, name or village');
  static String get tabOpen => _t('चालू काम', 'Open jobs');
  static String get tabDone => _t('पूरे हुए', 'Done');
  static String get newIntake => _t('मशीन जमा करें', 'New job');
  static String get quickJob => _t('तुरंत ठीक किया', 'Quick fix');
  static String get noJobs => _t('कोई काम नहीं है', 'No jobs');
  static String get overdue => _t('देर हो गई', 'Overdue');
  static String get today => _t('आज', 'Today');
  static String get tomorrow => _t('कल', 'Tomorrow');
  static String get dayAfter => _t('परसों', 'Day after');
  static String get statusReceived => _t('जमा', 'Received');
  static String get statusRepaired => _t('ठीक हो गया', 'Repaired');
  static String get statusDelivered => _t('दे दिया', 'Delivered');
  static String get statusReturned => _t('वापस', 'Returned');
  static String get connectError => _t(
    'सर्वर से जुड़ नहीं पाए — लैपटॉप चालू है?',
    "Can't reach the server — is the laptop on?",
  );
  static String get timeoutError =>
      _t('बहुत देर लग गई — फिर कोशिश करें', 'That took too long — try again');
  static String get needSettings => _t(
    'पहले सेटिंग में सर्वर का पता भरें',
    'First enter the server address in Settings',
  );
  static String get intakeTitle => _t('मशीन जमा करें', 'Take in machine');
  static String get quickTitle => _t('तुरंत ठीक किया', 'Fixed on the spot');
  static String get phone =>
      _t('फ़ोन नंबर (10 अंक)', 'Phone number (10 digits)');
  static String get oldCustomer => _t('पुराने ग्राहक', 'Returning customer');
  static String get pastJobs => _t('पिछले काम', 'Past jobs');
  static String get machinePhoto => _t('मशीन की फ़ोटो', 'Machine photo');
  static String get platePhoto =>
      _t('प्लेट/लेबल की फ़ोटो', 'Rating plate / label photo');
  static String get customerPhoto => _t('ग्राहक की फ़ोटो', 'Customer photo');
  static String get customerPhotoNote => _t(
    'ग्राहक से पूछ कर फ़ोटो लें',
    'Ask the customer before taking a photo',
  );
  static String get readingPlate =>
      _t('प्लेट पढ़ रहे हैं…', 'Reading the plate…');
  static String get speak => _t('बोलिए', 'Speak');
  static String get stopSpeak => _t('रोकिए', 'Stop');
  static String get listening => _t('सुन रहे हैं…', 'Listening…');
  static String get understanding => _t('समझ रहे हैं…', 'Understanding…');
  static String get hintIntake => _t(
    'नाम, गाँव, क्या ख़राबी है, कितना लगेगा, कब ले जाना है — बोलिए',
    'Say the name, village, the fault, the cost and when to pick it up (Hindi is fine)',
  );
  static String get hintQuick => _t(
    'क्या ठीक किया और कितने पैसे — बोलिए',
    'Say what you fixed and how much (Hindi is fine)',
  );
  static String get transcript =>
      _t('आपने बोला (सुधार सकते हैं)', 'You said (you can correct it)');
  static String get micDenied =>
      _t('माइक की इजाज़त चाहिए', 'Microphone permission is needed');
  static String get name => _t('नाम', 'Name');
  static String get customer => _t('ग्राहक', 'Customer');
  static String get village => _t('गाँव', 'Village');
  static String get appliance => _t('कौन सी मशीन', 'Which machine');
  static String get complaint => _t('शिकायत', 'Complaint');
  static String get diagnosis => _t('ख़राबी', 'Fault found');
  static String get estimate => _t('अनुमानित ख़र्च ₹', 'Estimated cost ₹');
  static String get pickupDate => _t('ले जाने की तारीख़', 'Pickup date');
  static String get pickDate => _t('तारीख़ चुनें', 'Pick a date');
  static String get workDone => _t('क्या किया', 'Work done');
  // Labels for amounts shown next to a ₹ icon and a ₹ value, so without their own ₹.
  static String get estimateLabel => _t('अनुमानित ख़र्च', 'Estimated cost');
  static String get totalLabel => _t('कुल', 'Total');
  static String get payment => _t('भुगतान', 'Payment');
  static String get finalAmount => _t('कुल ₹', 'Total ₹');
  static String get paidQ => _t('पैसे मिले?', 'Paid?');
  static String get cash => _t('नकद', 'Cash');
  static String get upiPay => 'UPI';
  static String get notYet => _t('अभी नहीं', 'Not yet');
  static String get machineInfo => _t('मशीन की जानकारी', 'Machine details');
  static String get brand => _t('कंपनी', 'Brand');
  static String get model => _t('मॉडल', 'Model');
  static String get rating => _t('रेटिंग (HP/वॉट)', 'Rating (HP/W)');
  static String get serial => _t('सीरियल नंबर', 'Serial number');
  static String get saveJob => _t('सेव करें', 'Save');
  static String get saving => _t('सेव हो रहा है…', 'Saving…');
  static String get writeNumber =>
      _t('यह नंबर मशीन पर लिख दें', 'Write this number on the machine');
  static String get ok => _t('ठीक है', 'OK');
  static String get quickSaved => _t('काम सेव हो गया', 'Job saved');
  static String get jobDetail => _t('काम का ब्योरा', 'Job details');
  static String get call => _t('कॉल करें', 'Call');
  static String get fixed => _t('ठीक हो गया', 'Repaired');
  static String get resend => _t('फिर से भेजें', 'Send again');
  static String get handedOver => _t('ग्राहक ले गया', 'Customer took it');
  static String get cannotFix =>
      _t('नहीं बनेगा, वापस किया', "Can't fix, returned");
  static String get confirmReturn => _t(
    'क्या यह मशीन बिना ठीक किए वापस की?',
    'Was this machine returned without repair?',
  );
  static String get yes => _t('हाँ', 'Yes');
  static String get no => _t('नहीं', 'No');
  static String get cancel => _t('रद्द करें', 'Cancel');
  static String get history => _t('इनके दूसरे काम', 'Their other jobs');
  static String get edit => _t('बदलें', 'Edit');
  static String get messagePreview =>
      _t('ग्राहक को संदेश', 'Message to customer');
  static String get sendWhatsapp => _t('WhatsApp पर भेजें', 'Send on WhatsApp');
  static String get sendMessageOnly =>
      _t('सिर्फ़ मैसेज भेजें', 'Send text only');
  static String get playVoice => _t('आवाज़ सुनें', 'Play voice note');
  static String get stopVoice => _t('रोकें', 'Stop');
  static String get preparing => _t('तैयार कर रहे हैं…', 'Preparing…');
  static String get loading => _t('लोड हो रहा है…', 'Loading…');
  static String get reparse => _t('फिर से समझें', 'Understand again');
  static String get theme => _t('रंग', 'Theme');
  static String get themeSystem => _t('फ़ोन जैसा', 'System');
  static String get themeLight => _t('हल्का', 'Light');
  static String get themeDark => _t('गहरा', 'Dark');
  static String get switchTheme => _t('हल्का/गहरा रंग', 'Light/dark');
  static String get errPhone => _t(
    'सही मोबाइल नंबर भरें (10 अंक)',
    'Enter a valid 10-digit mobile number',
  );
  static String get errName => _t('नाम भरें', 'Enter the name');
  static String get errAppliance => _t('मशीन चुनें', 'Choose the machine');
  static String get errAmount => _t('कुल रकम भरें', 'Enter the total amount');
  static String get fixErrors =>
      _t('लाल वाले खाने भरें', 'Please fill in the fields marked in red');
  static String get editJob => _t('काम बदलें', 'Edit job');
  static String get deleteJob => _t('मिटाएँ', 'Delete');
  static String get confirmDelete => _t(
    'यह काम हमेशा के लिए मिटाएँ? फ़ोटो और संदेश भी मिट जाएँगे।',
    'Delete this job for good? Its photos and messages go too.',
  );
  static String get deleted => _t('काम मिटा दिया', 'Job deleted');
  static String get changesSaved => _t('बदलाव सेव हो गए', 'Changes saved');
  static String get cancelWait => _t('रोकें', 'Cancel');
  static String secs(int n) => isHindi ? '$n सेकंड' : '${n}s';
  static String get retry => _t('फिर कोशिश करें', 'Try again');
  static String get paid => _t('पैसे मिल गए', 'Paid');
  static String get notPaid => _t('पैसे बाकी', 'Payment due');

  static const _appliancesHi = <String, String>{
    'water_pump': 'पानी पंप',
    'submersible': 'सबमर्सिबल',
    'fan': 'पंखा',
    'ac': 'एसी',
    'cooler': 'कूलर',
    'cutter': 'कटर मशीन',
    'mixer': 'मिक्सी',
    'induction': 'इंडक्शन चूल्हा',
    'heater': 'हीटर',
    'kettle': 'केतली',
    'iron': 'प्रेस (आयरन)',
    'other': 'अन्य',
  };

  static const _appliancesEn = <String, String>{
    'water_pump': 'Water pump',
    'submersible': 'Submersible',
    'fan': 'Fan',
    'ac': 'AC',
    'cooler': 'Cooler',
    'cutter': 'Cutter',
    'mixer': 'Mixer grinder',
    'induction': 'Induction cooktop',
    'heater': 'Heater',
    'kettle': 'Kettle',
    'iron': 'Iron',
    'other': 'Other',
  };

  static Map<String, String> get appliances =>
      isHindi ? _appliancesHi : _appliancesEn;

  static const applianceIcons = <String, IconData>{
    'water_pump': Icons.water_drop,
    'submersible': Icons.vertical_align_bottom,
    'fan': Icons.mode_fan_off,
    'ac': Icons.ac_unit,
    'cooler': Icons.air,
    'cutter': Icons.content_cut,
    'mixer': Icons.blender,
    'induction': Icons.countertops,
    'heater': Icons.local_fire_department,
    'kettle': Icons.coffee_maker,
    'iron': Icons.iron,
    'other': Icons.build,
  };

  static String applianceLabel(String? k) =>
      appliances[k] ?? (k == null ? '' : appliances['other']!);
  static IconData applianceIcon(String? k) => applianceIcons[k] ?? Icons.build;

  static String statusLabel(String s) {
    switch (s) {
      case 'received':
        return statusReceived;
      case 'repaired':
        return statusRepaired;
      case 'delivered':
        return statusDelivered;
      case 'returned':
        return statusReturned;
    }
    return s;
  }
}
