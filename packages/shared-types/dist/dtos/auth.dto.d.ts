export interface LoginDto {
    email: string;
    password: string;
}
export interface AuthTokensDto {
    accessToken: string;
    refreshToken: string;
}
export interface JwtPayload {
    sub: string;
    email: string;
    role: string;
    consultantId?: string;
    companyId?: string;
}
//# sourceMappingURL=auth.dto.d.ts.map