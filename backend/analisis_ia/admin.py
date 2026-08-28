from django.contrib import admin
from .models import AnalisisFacial


@admin.register(AnalisisFacial)
class AnalisisFacialAdmin(admin.ModelAdmin):
    list_display = ("id", "usuario", "forma_rostro", "tipo_cabello", "estado", "creado_en")
    list_filter = ("estado", "forma_rostro", "tipo_cabello")
    readonly_fields = [f.name for f in AnalisisFacial._meta.fields]
