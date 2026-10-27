package edu.ucaldas.devops.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.LocalTime;

@Entity
@Table(name = "landslide_reports")
public class LandslideReport {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @NotNull private LocalDate recordDate;
    @NotNull private LocalTime recordTime;
    @NotBlank @Size(max = 120) private String sector;
    @NotBlank @Size(max = 200) private String locationDescription;
    @NotBlank private String severity;
    @NotBlank private String affectedArea;
    @NotBlank private String status;
    @Size(max = 200) private String source;
    @Size(max = 1000) private String description;

    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public LocalDate getRecordDate(){return recordDate;} public void setRecordDate(LocalDate recordDate){this.recordDate=recordDate;}
    public LocalTime getRecordTime(){return recordTime;} public void setRecordTime(LocalTime recordTime){this.recordTime=recordTime;}
    public String getSector(){return sector;} public void setSector(String sector){this.sector=sector;}
    public String getLocationDescription(){return locationDescription;} public void setLocationDescription(String locationDescription){this.locationDescription=locationDescription;}
    public String getSeverity(){return severity;} public void setSeverity(String severity){this.severity=severity;}
    public String getAffectedArea(){return affectedArea;} public void setAffectedArea(String affectedArea){this.affectedArea=affectedArea;}
    public String getStatus(){return status;} public void setStatus(String status){this.status=status;}
    public String getSource(){return source;} public void setSource(String source){this.source=source;}
    public String getDescription(){return description;} public void setDescription(String description){this.description=description;}
}
