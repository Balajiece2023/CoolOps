import { TokenUser } from './auth';

declare global {
  namespace Express {
    interface Request {
      user?: TokenUser;
      rawBody?: string;
    }
  }
}
