// The appliance keys the contract allows, with the Hindi label the app shows.
export const APPLIANCES = {
  water_pump: 'पानी पंप',
  submersible: 'सबमर्सिबल',
  fan: 'पंखा',
  ac: 'एसी',
  cooler: 'कूलर',
  cutter: 'कटर मशीन',
  mixer: 'मिक्सी',
  induction: 'इंडक्शन चूल्हा',
  heater: 'हीटर',
  kettle: 'केतली',
  iron: 'प्रेस (आयरन)',
  other: 'अन्य',
};

export const APPLIANCE_KEYS = Object.keys(APPLIANCES);
export const STATUSES = ['received', 'repaired', 'delivered', 'returned'];
export const PAY_METHODS = ['cash', 'upi'];
