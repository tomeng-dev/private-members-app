import { Injectable, NotFoundException } from '@nestjs/common';
import { RoleName, UserStatus } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { UpsertBusinessPageDto } from './dto/business-page.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { CreateVehicleDto, UpdateVehicleDto } from './dto/vehicle.dto';
import { stripScripts } from './domain/sanitize.policy';

@Injectable()
export class ProfilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        vehicles: {
          where: { deletedAt: null },
          orderBy: { createdAt: 'desc' },
        },
        businessPage: true,
        roles: { include: { role: true } },
      },
    });
    if (!user || user.status === UserStatus.deleted)
      throw new NotFoundException();
    return this.toOwnerProfile(user);
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        firstName: dto.firstName?.trim(),
        lastName: dto.lastName?.trim(),
        phone: dto.phone,
        company: dto.company,
        title: dto.title,
        city: dto.city,
        state: dto.state,
        bio: dto.bio,
        showEmail: dto.showEmail,
        showPhone: dto.showPhone,
        showEventsAttended: dto.showEventsAttended,
      },
    });
    await this.audit.log({
      actorId: userId,
      action: 'profile.updated',
      targetType: 'user',
      targetId: userId,
    });
    return this.getMe(user.id);
  }

  async getPublicProfile(viewerId: string, memberId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: memberId },
      include: {
        vehicles: {
          where: { deletedAt: null, hiddenAt: null },
          orderBy: { createdAt: 'desc' },
        },
        businessPage: true,
      },
    });
    if (
      !user ||
      user.status === UserStatus.deleted ||
      user.status === UserStatus.suspended ||
      user.hiddenAt
    ) {
      throw new NotFoundException('Member not found');
    }
    return this.toPublicProfile(user);
  }

  async listMembers(q?: string, eventId?: string) {
    let attendedIds: string[] | undefined;
    if (eventId) {
      const checkins = await this.prisma.eventCheckin.findMany({
        where: { eventId },
        select: { userId: true },
      });
      attendedIds = checkins.map((c) => c.userId);
      if (!attendedIds.length) return [];
    }
    const users = await this.prisma.user.findMany({
      where: {
        status: UserStatus.active,
        hiddenAt: null,
        deletedAt: null,
        roles: { some: { role: { name: RoleName.member } } },
        ...(attendedIds
          ? { id: { in: attendedIds }, showEventsAttended: true }
          : {}),
        ...(q
          ? {
              OR: [
                { firstName: { contains: q } },
                { lastName: { contains: q } },
                { company: { contains: q } },
                { city: { contains: q } },
                {
                  vehicles: {
                    some: { make: { contains: q }, deletedAt: null },
                  },
                },
              ],
            }
          : {}),
      },
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
      take: 100,
      select: {
        id: true,
        firstName: true,
        lastName: true,
        company: true,
        title: true,
        city: true,
        state: true,
        foundingMember: true,
        avatarKey: true,
      },
    });
    return users;
  }

  async createVehicle(userId: string, dto: CreateVehicleDto) {
    if (dto.isPrimary) {
      await this.prisma.vehicle.updateMany({
        where: { userId, deletedAt: null },
        data: { isPrimary: false },
      });
    }
    const vehicle = await this.prisma.vehicle.create({
      data: {
        userId,
        make: dto.make.trim(),
        model: dto.model.trim(),
        year: dto.year,
        color: dto.color,
        plateNumber: dto.plateNumber,
        blurPlate: dto.blurPlate ?? true,
        estimatedValueUsd: dto.estimatedValueUsd,
        description: dto.description,
        isPrimary: dto.isPrimary ?? false,
        verificationStatus: 'draft',
      },
      include: { media: { where: { deletedAt: null, hiddenAt: null } } },
    });
    await this.audit.log({
      actorId: userId,
      action: 'vehicle.created',
      targetType: 'vehicle',
      targetId: vehicle.id,
    });
    return vehicle;
  }

  async updateVehicle(
    userId: string,
    vehicleId: string,
    dto: UpdateVehicleDto,
  ) {
    const existing = await this.prisma.vehicle.findFirst({
      where: { id: vehicleId, userId, deletedAt: null },
    });
    if (!existing) throw new NotFoundException('Vehicle not found');
    if (dto.isPrimary) {
      await this.prisma.vehicle.updateMany({
        where: { userId, deletedAt: null },
        data: { isPrimary: false },
      });
    }
    const vehicle = await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: {
        make: dto.make?.trim(),
        model: dto.model?.trim(),
        year: dto.year,
        color: dto.color,
        plateNumber: dto.plateNumber,
        blurPlate: dto.blurPlate,
        estimatedValueUsd: dto.estimatedValueUsd,
        description: dto.description,
        isPrimary: dto.isPrimary,
      },
      include: { media: { where: { deletedAt: null, hiddenAt: null } } },
    });
    await this.audit.log({
      actorId: userId,
      action: 'vehicle.updated',
      targetType: 'vehicle',
      targetId: vehicleId,
    });
    return vehicle;
  }

  async deleteVehicle(userId: string, vehicleId: string) {
    const existing = await this.prisma.vehicle.findFirst({
      where: { id: vehicleId, userId, deletedAt: null },
    });
    if (!existing) throw new NotFoundException('Vehicle not found');
    await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: { deletedAt: new Date() },
    });
    await this.audit.log({
      actorId: userId,
      action: 'vehicle.deleted',
      targetType: 'vehicle',
      targetId: vehicleId,
    });
    return { ok: true };
  }

  async upsertBusinessPage(userId: string, dto: UpsertBusinessPageDto) {
    // Basic sanitization: strip script tags from rich text fields
    const clean = stripScripts;
    const page = await this.prisma.businessPage.upsert({
      where: { userId },
      create: {
        userId,
        companyName: dto.companyName.trim(),
        services: clean(dto.services),
        background: clean(dto.background),
        website: dto.website,
        contactEmail: dto.contactEmail,
        contactPhone: dto.contactPhone,
        showContactEmail: dto.showContactEmail ?? true,
        showContactPhone: dto.showContactPhone ?? false,
      },
      update: {
        companyName: dto.companyName.trim(),
        services: clean(dto.services),
        background: clean(dto.background),
        website: dto.website,
        contactEmail: dto.contactEmail,
        contactPhone: dto.contactPhone,
        showContactEmail: dto.showContactEmail,
        showContactPhone: dto.showContactPhone,
        deletedAt: null,
        hiddenAt: null,
      },
    });
    await this.audit.log({
      actorId: userId,
      action: 'business_page.upserted',
      targetType: 'business_page',
      targetId: page.id,
    });
    return page;
  }

  async deleteBusinessPage(userId: string) {
    const page = await this.prisma.businessPage.findUnique({
      where: { userId },
    });
    if (!page) throw new NotFoundException();
    await this.prisma.businessPage.update({
      where: { userId },
      data: { deletedAt: new Date() },
    });
    await this.audit.log({
      actorId: userId,
      action: 'business_page.deleted',
      targetType: 'business_page',
      targetId: page.id,
    });
    return { ok: true };
  }

  async adminHide(
    actorId: string,
    target: { type: 'user' | 'vehicle' | 'business_page'; id: string },
    hide: boolean,
  ) {
    if (target.type === 'user') {
      await this.prisma.user.update({
        where: { id: target.id },
        data: { hiddenAt: hide ? new Date() : null },
      });
    } else if (target.type === 'vehicle') {
      await this.prisma.vehicle.update({
        where: { id: target.id },
        data: { hiddenAt: hide ? new Date() : null },
      });
    } else {
      await this.prisma.businessPage.update({
        where: { id: target.id },
        data: { hiddenAt: hide ? new Date() : null },
      });
    }
    await this.audit.log({
      actorId,
      action: hide ? `${target.type}.hidden` : `${target.type}.unhidden`,
      targetType: target.type,
      targetId: target.id,
    });
    return { ok: true };
  }

  async adminGetMember(memberId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: memberId },
      include: {
        vehicles: { where: { deletedAt: null } },
        businessPage: true,
        roles: { include: { role: true } },
      },
    });
    if (!user) throw new NotFoundException();
    return this.toOwnerProfile(user);
  }

  private toOwnerProfile(user: any) {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      company: user.company,
      title: user.title,
      city: user.city,
      state: user.state,
      bio: user.bio,
      avatarKey: user.avatarKey,
      foundingMember: user.foundingMember,
      membershipStatus: user.membershipStatus,
      showEmail: user.showEmail,
      showPhone: user.showPhone,
      showEventsAttended: user.showEventsAttended,
      hiddenAt: user.hiddenAt,
      roles: user.roles?.map((r: any) => r.role.name) ?? [],
      vehicles: (user.vehicles ?? []).map((v: any) => this.toVehicle(v, true)),
      businessPage:
        user.businessPage && !user.businessPage.deletedAt
          ? this.toBusiness(user.businessPage, true)
          : null,
    };
  }

  private toPublicProfile(user: any) {
    const page =
      user.businessPage &&
      !user.businessPage.deletedAt &&
      !user.businessPage.hiddenAt
        ? this.toBusiness(user.businessPage, false)
        : null;
    return {
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      company: user.company,
      title: user.title,
      city: user.city,
      state: user.state,
      bio: user.bio,
      avatarKey: user.avatarKey,
      foundingMember: user.foundingMember,
      email: user.showEmail ? user.email : undefined,
      phone: user.showPhone ? user.phone : undefined,
      vehicles: (user.vehicles ?? []).map((v: any) => this.toVehicle(v, false)),
      businessPage: page,
    };
  }

  private toVehicle(v: any, owner: boolean) {
    return {
      id: v.id,
      make: v.make,
      model: v.model,
      year: v.year,
      color: v.color,
      plateNumber: owner || !v.blurPlate ? v.plateNumber : undefined,
      blurPlate: v.blurPlate,
      estimatedValueUsd: owner ? v.estimatedValueUsd : undefined,
      description: v.description,
      verificationStatus: v.verificationStatus,
      isPrimary: v.isPrimary,
      hiddenAt: v.hiddenAt,
      media: v.media,
    };
  }

  private toBusiness(p: any, owner: boolean) {
    return {
      id: p.id,
      companyName: p.companyName,
      logoKey: p.logoKey,
      services: p.services,
      background: p.background,
      website: p.website,
      contactEmail: owner || p.showContactEmail ? p.contactEmail : undefined,
      contactPhone: owner || p.showContactPhone ? p.contactPhone : undefined,
      showContactEmail: p.showContactEmail,
      showContactPhone: p.showContactPhone,
      hiddenAt: p.hiddenAt,
    };
  }
}
