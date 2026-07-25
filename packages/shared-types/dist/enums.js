"use strict";
// ─── ENUMS COMPARTILHADOS ─────────────────────────────────────────────────────
// Definidos aqui uma vez — importados pelo backend (NestJS) e pelo web (Next.js)
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserRole = exports.ParticipantStatus = exports.ParticipationType = exports.TrainingStatus = exports.DemandStatus = exports.NoteType = exports.VehicleType = void 0;
var VehicleType;
(function (VehicleType) {
    VehicleType["LEVE"] = "LEVE";
    VehicleType["PESADO"] = "PESADO";
    VehicleType["MOTO"] = "MOTO";
})(VehicleType || (exports.VehicleType = VehicleType = {}));
var NoteType;
(function (NoteType) {
    NoteType["B"] = "B";
    NoteType["PM"] = "PM";
    NoteType["M"] = "M";
})(NoteType || (exports.NoteType = NoteType = {}));
var DemandStatus;
(function (DemandStatus) {
    DemandStatus["QUALIFICACAO"] = "QUALIFICACAO";
    DemandStatus["ANALISE"] = "ANALISE";
    DemandStatus["PROPOSTA"] = "PROPOSTA";
    DemandStatus["AGENDAMENTO"] = "AGENDAMENTO";
    DemandStatus["CONCLUIDO"] = "CONCLUIDO";
    DemandStatus["PERDIDO"] = "PERDIDO";
})(DemandStatus || (exports.DemandStatus = DemandStatus = {}));
var TrainingStatus;
(function (TrainingStatus) {
    TrainingStatus["PLANEJADO"] = "PLANEJADO";
    TrainingStatus["EM_ANDAMENTO"] = "EM_ANDAMENTO";
    TrainingStatus["CONCLUIDO"] = "CONCLUIDO";
    TrainingStatus["CANCELADO"] = "CANCELADO";
})(TrainingStatus || (exports.TrainingStatus = TrainingStatus = {}));
var ParticipationType;
(function (ParticipationType) {
    ParticipationType["SOMENTE_TEORICA"] = "SOMENTE_TEORICA";
    ParticipationType["TEORICA_E_PRATICA"] = "TEORICA_E_PRATICA";
})(ParticipationType || (exports.ParticipationType = ParticipationType = {}));
var ParticipantStatus;
(function (ParticipantStatus) {
    ParticipantStatus["PENDENTE"] = "PENDENTE";
    ParticipantStatus["EM_AVALIACAO"] = "EM_AVALIACAO";
    ParticipantStatus["APROVADO"] = "APROVADO";
    ParticipantStatus["NECESSITA_REAVALIACAO"] = "NECESSITA_REAVALIACAO";
})(ParticipantStatus || (exports.ParticipantStatus = ParticipantStatus = {}));
var UserRole;
(function (UserRole) {
    UserRole["ADMIN"] = "ADMIN";
    UserRole["CONSULTANT"] = "CONSULTANT";
    UserRole["CLIENT"] = "CLIENT";
})(UserRole || (exports.UserRole = UserRole = {}));
//# sourceMappingURL=enums.js.map