/// Curated city list — (display name, lat, lng, IANA timezone). Stands in for
/// the Google Places autocomplete/geocode proxy until a real API key is
/// configured (see backend/README.md) — shared by every screen that collects
/// a birth place (onboarding's Birth Place step, Edit Birth Data).
const kCuratedCities = <(String, double, double, String)>[
  ('Mumbai, Maharashtra, India', 19.0760, 72.8777, 'Asia/Kolkata'),
  ('Delhi, India', 28.6139, 77.2090, 'Asia/Kolkata'),
  ('Pune, Maharashtra, India', 18.5204, 73.8567, 'Asia/Kolkata'),
  ('Bengaluru, Karnataka, India', 12.9716, 77.5946, 'Asia/Kolkata'),
  ('Ahmedabad, Gujarat, India', 23.0225, 72.5714, 'Asia/Kolkata'),
];
