import { Role } from '@prisma/client';

export interface TokenUser {
  userId: string;
  email: string;
  role: Role;
  technicianId?: string;
}

