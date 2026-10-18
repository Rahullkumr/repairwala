// GET /api/customers/by-phone/:phone: is this a returning customer, and what did we fix before?
import { getCustomerByPhone, jobsOfCustomer } from '../db.js';
import { phone as cleanPhone } from '../lib/http.js';

export default async function customerRoutes(app) {
  app.get('/api/customers/by-phone/:phone', async (req) => {
    const phone = cleanPhone(req.params.phone);
    const customer = phone ? getCustomerByPhone(phone) : null;
    return { customer, jobs: customer ? jobsOfCustomer(customer.id) : [] };
  });
}
